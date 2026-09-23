--- Command handler registration for ascii-ui.
---
--- `register_handlers` wires up the command bus so that dispatched commands
--- trigger the appropriate side effects (window close, cursor movement,
--- segment interaction, rerender, etc.).
---
--- All handlers receive the dispatched command as their sole argument.
--- Commands are immutable — handlers MUST NOT mutate command tables.
---
--- @module ascii-ui.handlers

local Buffer = require("ascii-ui.buffer.buffer")
local BufferLine = require("ascii-ui.buffer.bufferline")
local Cursor = require("ascii-ui.cursor")
local Segment = require("ascii-ui.buffer.segment")
local error_handler = require("ascii-ui.utils.error_handler")
local fiber = require("ascii-ui.fiber")
local i = require("ascii-ui.interaction_type")
local logger = require("ascii-ui.logger")
local user_interations = require("ascii-ui.user_interactions")

local M = {}

--- @param err ascii-ui.Error
--- @return ascii-ui.Buffer
local function render_error_buffer(err)
	local lines = error_handler.render_error_to_lines(err)
	local buffer = Buffer.new()
	for _, line in ipairs(lines) do
		buffer:add(BufferLine.new(Segment:new({ content = line, color = { fg = "#ff0000" } })))
	end
	return buffer
end

--- Maps a CursorDirection to the appropriate buffer search function.
--- @param direction ascii-ui.CursorDirection
--- @return fun(buffer: ascii-ui.Buffer, position: ascii-ui.Position): { found: boolean, pos: ascii-ui.Position }
local function search_fn_for_direction(direction)
	if direction == "EAST" or direction == "SOUTH" then
		return Buffer.find_next_focusable
	end
	return Buffer.find_last_focusable
end

--- @class ascii-ui.HandlerConfig
--- @field bus ascii-ui.EventBus The command bus
--- @field window ascii-ui.Window The viewport
--- @field fiberRootGetter fun(): ascii-ui.RootFiberNode Returns current fiber root
--- @field fiberRootSetter fun(root: ascii-ui.RootFiberNode) Updates fiber root reference
--- @field renderedBufferGetter fun(): ascii-ui.Buffer Returns current rendered buffer
--- @field renderedBufferSetter fun(buffer: ascii-ui.Buffer) Updates rendered buffer reference
--- @field inputHandler? ascii-ui.InputHandler Optional input handler for pre-render guard
--- @field onClose? fun() Optional callback invoked when the window is closed (e.g. to untrack the mount)

--- Registers all command handlers on the given bus.
--- @param config ascii-ui.HandlerConfig Configuration table with dependencies
function M.register_handlers(config)
	local bus = config.bus
	local window = config.window
	local fiberRootGetter = config.fiberRootGetter
	local fiberRootSetter = config.fiberRootSetter
	local renderedBufferGetter = config.renderedBufferGetter
	local renderedBufferSetter = config.renderedBufferSetter
	local inputHandler = config.inputHandler
	local onClose = config.onClose

	-- CLOSE_WINDOW: close window, unmount fiber tree, detach interactions, clear bus
	bus:on("CLOSE_WINDOW", function()
		logger.info("Handling CLOSE_WINDOW for window %d", window:get_id())

		if onClose then
			onClose()
		end

		-- Detach from user interactions
		user_interations:instance():detach_buffer(window:get_bufnr())
		vim.on_key(nil, window:get_ns_id())

		-- Close the window
		window:close()
		logger.info("Closed window %d", window:get_id())
		-- Unmount the fiber tree
		local fiberRoot = fiberRootGetter()
		if fiberRoot then
			fiberRoot:unmount()
		end

		-- Clear the bus (removes all listeners)
		bus:clear()
	end)

	-- MOVE_WINDOW: move the floating window to a new position
	bus:on("MOVE_WINDOW", function(command)
		logger.debug("Handling MOVE_WINDOW to %s", vim.inspect(command.position))
		if window:is_open() then
			window:move_to(command.position)
		end
	end)

	-- CURSOR_MOVE: find next/last focusable segment and move cursor
	bus:on("CURSOR_MOVE", function(command)
		logger.debug("Handling CURSOR_MOVE direction=%s", command.direction)
		local rendered_buffer = renderedBufferGetter()
		local search_fn = search_fn_for_direction(command.direction)

		vim.schedule(function()
			local result = search_fn(rendered_buffer, command.position)
			if result then
				local next_position = result.pos
				Cursor.move_to(next_position, window:get_id(), window:get_bufnr())
				logger.debug("Cursor moved to: %s", vim.inspect(next_position))
			end
		end)
	end)

	-- SELECT: find segment at position and invoke its SELECT interaction
	bus:on("SELECT", function(command)
		logger.debug("Handling SELECT at %s", vim.inspect(command.position))
		user_interations:instance():interact({
			buffer_id = window:get_bufnr(),
			position = command.position,
			interaction_type = i.SELECT,
		})
	end)

	-- HOVER: find segment at position and invoke its HOVER interaction
	bus:on("HOVER", function(command)
		logger.debug("Handling HOVER at %s", vim.inspect(command.position))
		user_interations:instance():interact({
			buffer_id = window:get_bufnr(),
			position = command.position,
			interaction_type = i.HOVER,
		})
	end)

	-- INPUT: find segment at position and invoke its INPUT interaction
	bus:on("INPUT", function(command)
		logger.debug("Handling INPUT at %s", vim.inspect(command.position))
		user_interations:instance():interact({
			buffer_id = window:get_bufnr(),
			position = command.position,
			interaction_type = i.INPUT,
		})
	end)

	-- STATE_CHANGE: rerender the component tree
	bus:on("STATE_CHANGE", function()
		local rerender_start = vim.uv.hrtime()
		logger.info("------------------")
		logger.info("Rerendering component")
		logger.info("------------------")

		local fiberRoot = fiberRootGetter()
		local rendered_buffer = renderedBufferGetter()
		local current_lines_count = rendered_buffer:height()

		logger.info("Rerendering on state change for window %d and buffer %d", window:get_id(), window:get_bufnr())

		-- Pre-render guard: save editing line state if in insert mode
		local restore = inputHandler and inputHandler:pre_render_guard() or function() end

		local rerender_ok, new_fiberRoot, new_buffer = xpcall(function()
			local root = fiber.rerender(fiberRoot)
			return root, root:get_buffer()
		end, function(err)
			local err_type = "render"
			local component_path = "unknown"
			local message = tostring(err)

			local parsed_type, parsed_path, parsed_msg = err:match("^%[([^%]]+)%] in <([^>]+)>: (.+)$")
			if parsed_type then
				err_type = parsed_type
				component_path = parsed_path
				message = parsed_msg
			end

			return error_handler.create_error(err_type, component_path, message)
		end)

		if not rerender_ok then
			-- Render error to viewport
			local error_buffer = render_error_buffer(new_fiberRoot)
			window:update(error_buffer)
			logger.error("Rerender error: %s", vim.inspect(new_fiberRoot))
			restore() -- still try to restore
			return
		end

		-- Preserve the bus reference on the new root
		new_fiberRoot.bus = bus
		fiberRootSetter(new_fiberRoot)
		renderedBufferSetter(new_buffer)

		fiber.debugPrint(new_fiberRoot, logger.debug)

		local new_lines_count = new_buffer:height()
		window:update(new_buffer)

		-- Restore editing line content after update (re-render guard)
		restore()

		-- Rebind the buffer to user interactions
		user_interations:instance():attach_buffer(new_buffer, window:get_bufnr())

		if current_lines_count ~= new_lines_count then
			logger.info("Window %d resized from %d to %d lines", window:get_id(), current_lines_count, new_lines_count)

			-- If cursor is no longer on a focusable segment, move to next focusable
			local current_segment = new_buffer:find_segment_by_position(Cursor.current_position())
			logger.debug("Current segment: %s", vim.inspect(current_segment))
			if not current_segment or not current_segment:is_focusable() then
				logger.debug("Current segment is not focusable, moving to next focusable segment")
				local position = Cursor.current_position()
				local result = new_buffer:find_next_focusable(position)

				logger.debug("next position: %s", vim.inspect(result))
				local next_position = result.pos
				vim.schedule(function()
					Cursor.move_to(next_position, window:get_id())
				end)
			end
		end

		local rerender_elapsed_ns = vim.uv.hrtime() - rerender_start
		logger.info("Rerendering time: %.3f ms", rerender_elapsed_ns / 1e6)
	end)

	-- UNMOUNT: unmount the fiber tree (without closing window)
	bus:on("UNMOUNT", function()
		logger.info("Handling UNMOUNT for window %d", window:get_id())
		local fiberRoot = fiberRootGetter()
		if fiberRoot then
			fiberRoot:unmount()
		end
	end)
end

return M
