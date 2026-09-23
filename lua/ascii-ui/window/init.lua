local Cursor = require("ascii-ui.cursor")
local highlights = require("ascii-ui.highlights")
local logger = require("ascii-ui.logger")

---@alias ascii-ui.WindowOpts { width?: integer, height?: integer }

--- The Viewport interface defines the contract that all rendering targets must satisfy.
---
--- `ascii-ui.mount` accepts any object implementing this interface as its optional second
--- argument, allowing you to render UI into targets other than a Neovim floating window.
---
--- Built-in implementations:
---   - `ascii-ui.Window`          — centered floating Neovim window (default)
---   - `ascii-ui.StdoutViewport`  — terminal stdout via ANSI escape codes
---
--- To implement a custom viewport, create a table whose metatable provides all the
--- methods listed below, then pass an instance to `ui.mount`:
---
--- ```lua
--- local ui = require("ascii-ui")
---
--- ---@class MyViewport : ascii-ui.Viewport
--- local MyViewport = {}
--- MyViewport.__index = MyViewport
---
--- function MyViewport.new() return setmetatable({}, MyViewport) end
--- function MyViewport.open(_) end
--- function MyViewport.close(_) end
--- function MyViewport:update(buffer) ... end   -- called every frame
--- function MyViewport.is_focused(_) return false end
--- function MyViewport.enable_edits(_) end
--- function MyViewport.disable_edits(_) end
--- function MyViewport.get_id(_) return -1 end
--- function MyViewport.get_bufnr(_) return -1 end
--- function MyViewport.get_ns_id(_) return -1 end
---
--- ui.mount(MyComponent, MyViewport.new())
--- ```
---
--- Methods that are not relevant for a given target (e.g. `get_bufnr` for a non-Neovim
--- target) should return `-1` as a sentinel value.
---@class ascii-ui.Viewport
---@field get_id     fun(self: ascii-ui.Viewport): integer   Returns the Neovim window id, or -1 if not applicable.
---@field get_bufnr  fun(self: ascii-ui.Viewport): integer   Returns the Neovim buffer number, or -1 if not applicable.
---@field get_ns_id  fun(self: ascii-ui.Viewport): integer   Returns the Neovim namespace id, or -1 if not applicable.
---@field open       fun(self: ascii-ui.Viewport)            Opens / initialises the viewport.
---@field close      fun(self: ascii-ui.Viewport)            Closes / tears down the viewport.
---@field update     fun(self: ascii-ui.Viewport, buffer: ascii-ui.Buffer)  Renders the given buffer to the target. Called every frame.
---@field is_focused fun(self: ascii-ui.Viewport): boolean   Returns true when the viewport currently has user focus.
---@field enable_edits  fun(self: ascii-ui.Viewport)         Allows the user to type into the viewport (e.g. for Input widgets).
---@field disable_edits fun(self: ascii-ui.Viewport)         Reverts the viewport to read-only mode.

--- The default `ascii-ui.Viewport` implementation.
---
--- `Window` opens a centered Neovim floating window and is the viewport used by
--- `ui.mount` when no explicit viewport is provided.
---
--- ```lua
--- local ui = require("ascii-ui")
---
--- -- Explicit construction (equivalent to the default behaviour of ui.mount):
--- local win = require("ascii-ui.window").new({ width = 60, height = 20 })
--- ui.mount(MyComponent, win)
---
--- -- Default (Window is created automatically):
--- ui.mount(MyComponent)
--- ```
---@class ascii-ui.Window : ascii-ui.Viewport
---@field winid integer  Neovim window handle, available after `open()`.
---@field bufnr integer  Neovim buffer handle, available after `open()`.
---@field ns_id integer  Neovim namespace id used for highlight extmarks.
---@field opts ascii-ui.WindowOpts
local Window = {
	---@type ascii-ui.WindowOpts
	default_opts = { width = 40, height = 20 },
}
Window.__index = Window

--- Creates a new Window instance. The window is **not** opened yet; call `open()` to
--- create the Neovim buffer and floating window.
---@param opts? ascii-ui.WindowOpts  Optional size overrides. Defaults: width=40, height=20.
---@return ascii-ui.Window
function Window.new(opts)
	opts = opts or {}
	opts = vim.tbl_extend("force", Window.default_opts, opts)

	-- set default color
	local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
	vim.api.nvim_set_hl(0, highlights.DEFAULT, { fg = hl.fg, bg = hl.bg })

	-- set theme colors (per-token groups + legacy SELECTION/BUTTON)
	require("ascii-ui.theme").apply_highlights()

	-- set custom colors
	local ns_id = vim.api.nvim_create_namespace("ascii-ui")

	local state = {
		winid = nil,
		bufnr = nil,
		ns_id = ns_id,
		opts = opts,
		edits_enabled = false,
		-- last rendered dimensions; used to skip redundant nvim_win_set_config calls
		last_width = nil,
		last_height = nil,
	}

	setmetatable(state, Window)

	return state
end

--- Opens the floating window. Creates a scratch buffer, then a centered floating
--- window over the current editor layout. Sets up window key-maps.
--- Must be called before `update()`.
function Window:open()
	-- Create a new unlisted, scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- current window size
	local width = vim.api.nvim_win_get_width(0)
	local height = vim.api.nvim_win_get_height(0)
	local center = { line = math.floor(height / 2), col = math.floor(width / 2) }

	-- Open a floating window with the new buffer
	local win_width = self.opts.width or Window.default_opts.width or 40
	local win_height = self.opts.height or Window.default_opts.height or 20
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = center.col - math.floor(win_width / 2),
		row = center.line - math.floor(win_height / 2),
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_win_get_buf(win)

	-- Disable undo history: this is a scratch render buffer, not a user-edited file.
	-- Without this, every nvim_buf_set_lines call allocates an undo entry.
	vim.api.nvim_set_option_value("undolevels", -1, { buf = buf })
	-- Keep the buffer permanently modifiable; we guard against user edits via
	-- keymaps and interaction_type, not via the modifiable flag.
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	-- winhl never changes after open; set it once here instead of on every frame.
	vim.api.nvim_set_option_value("winhl", ("Normal:%s"):format(highlights.DEFAULT), { win = win })

	self.winid = win
	self.bufnr = buf
end

--- Get the position of the window
--- @return ascii-ui.Position
function Window:position()
	local pos = vim.api.nvim_win_get_position(self.winid)
	return {
		line = pos[1],
		col = pos[2],
	}
end

--- Move the window to a specific position
--- @param position ascii-ui.Position
function Window:move_to(position)
	if self:is_close() then
		error("Cannot move window: window or buffer is not open")
	end
	vim.api.nvim_win_set_config(self.winid, {
		relative = "editor",
		row = position.line,
		col = position.col,
	})
end

--- Allows the buffer to be edited by the user (used by Input widgets).
--- Errors if the window is not open.
function Window:enable_edits()
	if self:is_close() then
		error("Cannot enable edits: window or buffer is not open")
	end
	logger.debug("Edits are enabled for window/buffer (%d/%d)", self.winid, self.bufnr)
	self.edits_enabled = true
end

--- Reverts the buffer to read-only (non-modifiable) mode.
--- Errors if the window is not open.
function Window:disable_edits()
	if self:is_close() then
		error("Cannot disable edits: window or buffer is not open")
	end
	logger.debug("Edits are disabled for window/buffer (%d/%d)", self.winid, self.bufnr)
	self.edits_enabled = false
end

---@return boolean
function Window:is_open()
	return self.winid ~= nil or self.bufnr ~= nil
end

function Window:is_close()
	return not self:is_open()
end

--- Closes the floating window and releases the buffer handle.
--- After this call `winid` and `bufnr` are `nil`.
function Window:close()
	vim.api.nvim_win_close(self.winid, true)
	self.winid = nil
	self.bufnr = nil
end

--- Renders `buffer` into the Neovim window.
--- Schedules a `vim.schedule` call that writes lines, applies highlights/colors,
--- resizes the floating window to match the buffer dimensions and adjusts scroll.
--- Errors if the window is not open.
---@param buffer ascii-ui.Buffer
function Window:update(buffer)
	logger.debug("Updating window with id %s and bufnr %s", self.winid, self.bufnr)

	if not self:is_open() then
		error("Window is not open")
	end
	vim.schedule(function()
		-- Guard against the race where close() ran before this callback executed.
		-- Without this check, self.bufnr / self.winid are nil and every subsequent
		-- nvim_* call that receives { buf = nil } silently targets buf=0 (the current
		-- buffer), corrupting whatever buffer is active at that moment.
		if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
			return
		end
		if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
			return
		end

		-- buffer content
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, buffer:to_lines())

		-- resize window only when dimensions actually changed
		local w, h = buffer:width(), buffer:height()
		if w ~= self.last_width or h ~= self.last_height then
			vim.api.nvim_win_set_config(self.winid, { width = w, height = h })
			self.last_width = w
			self.last_height = h
		end
		-- adjust scroll
		vim.api.nvim_win_call(0, function()
			local win = vim.api.nvim_get_current_win()
			local curpos = Cursor.current_position()

			-- Move cursor to top, scroll, restore
			vim.api.nvim_win_set_cursor(win, { 1, 0 })
			Cursor.move_to({ line = 1, col = 0 }, win)
			vim.cmd("normal! zt")
			Cursor.move_to(curpos, win)
		end)

		-- coloring
		local function apply_highlight()
			vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)

			for segment_result in buffer:iter_colored_segments() do
				local pos = segment_result.position
				local segment = segment_result.segment
				local end_col = pos.col + segment:raw_len()

				if segment.highlight then
					vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, pos.line - 1, pos.col - 1, {
						end_col = end_col - 1,
						strict = false,
						hl_group = segment.highlight,
					})
				end

				if segment.color then
					local hl_group = segment.color:to_hl_group()

					vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, pos.line - 1, pos.col - 1, {
						end_col = end_col - 1,
						strict = false,
						hl_group = hl_group,
					})
				end
			end
		end

		apply_highlight()
	end)
end

--- Returns `true` when this window is the currently focused Neovim window.
--- @return boolean is_focused
function Window:is_focused()
	local cur_win = vim.api.nvim_get_current_win()

	return self.winid == cur_win
end

--- Returns the Neovim window handle (`winid`). Available after `open()`.
---@return integer
function Window:get_id()
	return self.winid
end

--- Returns the Neovim buffer handle (`bufnr`). Available after `open()`.
---@return integer
function Window:get_bufnr()
	return self.bufnr
end

--- Returns the Neovim namespace id used for color/highlight extmarks.
---@return integer
function Window:get_ns_id()
	return self.ns_id
end

return Window
