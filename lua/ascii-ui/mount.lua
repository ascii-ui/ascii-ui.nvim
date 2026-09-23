local Buffer = require("ascii-ui.buffer.buffer")
local BufferLine = require("ascii-ui.buffer.bufferline")
local Command = require("ascii-ui.commands")
local Cursor = require("ascii-ui.cursor")
local EventBus = require("ascii-ui.events")
local InputHandler = require("ascii-ui.input-handler")
local Segment = require("ascii-ui.buffer.segment")
local Window = require("ascii-ui.window")
local error_handler = require("ascii-ui.utils.error_handler")
local handlers = require("ascii-ui.handlers")
local i = require("ascii-ui.interaction_type")
local initialize_window_keymaps = require("ascii-ui.window.keymaps")
local logger = require("ascii-ui.logger")
local user_interations = require("ascii-ui.user_interactions")

local fiber = require("ascii-ui.fiber")
local render = fiber.render
local is_callable = require("ascii-ui.utils.is_callable")

--- Records of every currently mounted UI. Used by `rerender_all()` so global
--- visual changes (e.g. `ui.setTheme()`) can re-render all viewports without
--- touching hook state.
---@type { bus: ascii-ui.EventBus, window: ascii-ui.Viewport, fiberRootGetter: fun(): ascii-ui.RootFiberNode }[]
local active_mounts = {}

---@param bus ascii-ui.EventBus
local function forget_mount(bus)
	for idx, record in ipairs(active_mounts) do
		if record.bus == bus then
			table.remove(active_mounts, idx)
			return
		end
	end
end

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

--- Mounts a root component into a viewport and starts the render loop.
---
--- The simplest call opens a centered Neovim floating window automatically:
--- ```lua
--- local ui = require("ascii-ui")
--- ui.mount(MyComponent)
--- ```
---
--- Pass an explicit viewport to render into a different target.
--- Any object that satisfies the `ascii-ui.Viewport` interface is accepted:
---
--- ```lua
--- -- Built-in: stdout (useful for headless scripts / CI)
--- local ui = require("ascii-ui")
--- local viewport = ui.viewports.StdoutViewport.new()
--- ui.mount(MyComponent, viewport)
--- ```
---
--- ```lua
--- -- Built-in: Neovim floating window with custom dimensions
--- local ui   = require("ascii-ui")
--- local Win  = require("ascii-ui.window")
--- ui.mount(MyComponent, Win.new({ width = 80, height = 24 }))
--- ```
---
--- The viewport lifecycle is:
---   1. `viewport:open()`   — called once, immediately after the first render
---   2. `viewport:update(buffer)` — called on every state-change re-render
---   3. `viewport:close()` — called when the `WinClosed` autocmd fires
---
--- @note When `viewport` is a non-Neovim target (e.g. `StdoutViewport`), the
--- autocmd and `vim.on_key` bindings that are registered below will fire but
--- have no visible effect because `viewport:is_focused()` returns `false` and
--- `viewport:get_id()` / `viewport:get_bufnr()` return `-1`.
---
---@param RootComponent ascii-ui.FunctionalComponent  The root component to render.
---@param viewport? ascii-ui.Viewport  Rendering target. Defaults to a new `ascii-ui.Window`.
---@return integer bufnr  The buffer number used by the viewport (`-1` for non-Neovim targets).
local M = {}

function M.mount(RootComponent, viewport)
	local start = vim.uv.hrtime()
	logger.info("------------------")
	logger.info("Mounting component")
	logger.info("------------------")
	if not is_callable(RootComponent) and RootComponent.__is_a_component then
		error(vim.inspect(RootComponent))
		error("should be a functional component. Found: " .. type(RootComponent))
	end

	-- create an isolated event bus for this mount
	local bus = EventBus.new()

	-- does first render with error handling
	local fiberRoot, rendered_buffer
	-- Use closures to hold mutable references that handlers can access
	local current_fiberRoot = nil
	local current_rendered_buffer = nil

	local fiberRootGetter = function()
		return current_fiberRoot
	end
	local fiberRootSetter = function(root)
		current_fiberRoot = root
	end
	local renderedBufferGetter = function()
		return current_rendered_buffer
	end
	local renderedBufferSetter = function(buffer)
		current_rendered_buffer = buffer
	end
	local render_ok, render_err = xpcall(function()
		fiberRoot = render(RootComponent)
		return fiberRoot:get_buffer()
	end, function(err)
		-- Parse error message to extract component path and message
		local err_type = "render"
		local component_path = "unknown"
		local message = tostring(err)

		-- Try to parse the error format: [type] in <path>: message
		local parsed_type, parsed_path, parsed_msg = err:match("^%[([^%]]+)%] in <([^>]+)>: (.+)$")
		if parsed_type then
			err_type = parsed_type
			component_path = parsed_path
			message = parsed_msg
		end

		return error_handler.create_error(err_type, component_path, message)
	end)

	if not render_ok then
		-- Render error to viewport
		local error_buffer = render_error_buffer(render_err)
		local window = viewport or Window.new({ width = error_buffer:width(), height = error_buffer:height() })
		window:open()
		window:update(error_buffer)
		logger.error("Render error: %s", vim.inspect(render_err))
		return window:get_bufnr()
	end

	rendered_buffer = render_err -- render_err contains the buffer from the xpcall success

	-- Set the current references for handlers
	current_fiberRoot = fiberRoot
	current_rendered_buffer = rendered_buffer

	-- inject the bus so hooks (use_state) can trigger state_change on this instance only
	fiberRoot.bus = bus

	fiber.debugPrint(fiberRoot, logger.debug)

	fiber.debugPrint(fiberRoot, logger.debug)

	-- spawns a window (or use the provided viewport)
	local window = viewport or Window.new({ width = rendered_buffer:width(), height = rendered_buffer:height() })
	window:open()

	-- Track which line is being edited (for Input component insert mode)
	-- NOTE: Must be defined BEFORE InputHandler and register_handlers
	local editing_input_line = nil
	local editing_input_line_getter = function()
		return editing_input_line
	end
	local editing_input_line_setter = function(line)
		editing_input_line = line
	end

	-- Create input handler with injected dependencies
	local input_handler = InputHandler.new({
		window = window,
		renderedBufferGetter = renderedBufferGetter,
		editingLineGetter = editing_input_line_getter,
		editingLineSetter = editing_input_line_setter,
	})
	input_handler:setup()

	-- Register command handlers with config table
	handlers.register_handlers({
		bus = bus,
		window = window,
		fiberRootGetter = fiberRootGetter,
		fiberRootSetter = fiberRootSetter,
		renderedBufferGetter = renderedBufferGetter,
		renderedBufferSetter = renderedBufferSetter,
		inputHandler = input_handler,
		onClose = function()
			forget_mount(bus)
		end,
	})

	-- Track this mount so global visual changes can re-render it later.
	table.insert(active_mounts, { bus = bus, window = window, fiberRootGetter = fiberRootGetter })

	-- Set up window keymaps (now that we have the bus)
	initialize_window_keymaps(window, bus)

	-- updates the window with the rendered buffer
	window:update(rendered_buffer)

	-- binds to user interaction
	user_interations:instance():attach_buffer(rendered_buffer, window:get_bufnr())
	logger.info("Attached buffer %s to user interactions", window:get_bufnr())

	local key_map = {
		["l"] = { direction = "EAST", interaction = i.CURSOR_MOVE_RIGHT, search_fn = Buffer.find_next_focusable },
		["h"] = { direction = "WEST", interaction = i.CURSOR_MOVE_LEFT, search_fn = Buffer.find_last_focusable },
		["j"] = { direction = "SOUTH", interaction = i.CURSOR_MOVE_DOWN, search_fn = Buffer.find_focusable_below },
		["k"] = { direction = "NORTH", interaction = i.CURSOR_MOVE_UP, search_fn = Buffer.find_focusable_above },
	}

	vim.on_key(function(key, _)
		if not window:is_focused() then
			return
		end
		local action = key_map[key]
		if not action then
			return
		end

		local position = Cursor.current_position()

		-- Trigger the cursor move interaction on the segment
		user_interations:instance():interact({
			buffer_id = window:get_bufnr(),
			position = position,
			interaction_type = action.interaction,
		})

		-- Dispatch cursor move command
		bus:dispatch(Command.CursorMove({
			direction = action.direction,
			position = position,
		}))
	end, window:get_ns_id())

	-- Single CursorMoved autocmd handles inputable-segment detection.
	-- Position tracking (for direction detection) is handled by cursor.lua's own autocmd.
	local cursor_autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
		callback = function(args)
			-- enable/disable edits based on whether cursor is on an inputable segment
			local win_id = tonumber(args.match)
			if win_id ~= window:get_id() then
				return
			end
			local current_buffer = renderedBufferGetter()
			local segment = current_buffer:find_segment_by_position(Cursor.current_position())
			if not segment then
				return
			end
			if segment:is_inputable() then
				window:enable_edits()
			else
				window:disable_edits()
			end
		end,
	})

	-- binds to window close event (handles external closures like :close or :quit)
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(args)
			local win_id = tonumber(args.match)

			if win_id ~= window:get_id() then
				return -- not our window
			end

			forget_mount(bus)

			-- Clean up the cursor autocmd
			vim.api.nvim_del_autocmd(cursor_autocmd_id)

			-- Clean up input handler autocmds and keymaps
			input_handler:teardown()

			-- Unmount the fiber tree to clean up effects and timers
			local root = fiberRootGetter()
			if root and root.unmount then
				root:unmount()
			end

			-- Trigger any remaining ui_close listeners (backward compatibility)
			bus:trigger("ui_close")
		end,
	})

	-- Trigger initial state change to run effects after first render
	bus:dispatch(Command.StateChange({ prop = "initial", value = true }))

	local elapsed_ns = vim.uv.hrtime() - start
	logger.info("First render time: %.3f ms", elapsed_ns / 1e6)
	return window:get_bufnr()
end

--- Re-render every mounted UI (marks all fiber trees for update, then runs
--- the regular state-change render path per mount). Hook state is preserved:
--- only the render output refreshes. Used by `ui.setTheme()` so a runtime
--- theme switch updates all visible viewports.
function M.rerender_all()
	for _, record in ipairs(active_mounts) do
		local root = record.fiberRootGetter()
		if root then
			root:reset()
			for node in root:iter() do
				node.tag = "UPDATE"
			end
			record.bus:dispatch(Command.StateChange({ prop = "theme", value = true }))
		end
	end
end

-- The module stays callable (`ui.mount(Component)`) while also exposing
-- `rerender_all` for global visual updates like `ui.setTheme()`.
setmetatable(M, {
	__call = function(_, ...)
		return M.mount(...)
	end,
})

return M
