local Cursor = require("ascii-ui.cursor")
local async = require("ascii-ui.utils.async")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

--- @class ascii-ui.testing.E2EScreen : ascii-ui.testing.Screen
--- @field private _bufnr integer
--- @tag ascii-ui.testing.E2EScreen
local E2EScreen = {}
E2EScreen.__index = E2EScreen

-- Inherit all methods from Screen
setmetatable(E2EScreen, { __index = testing.Screen })

--- Mounts a component in a real Neovim window for e2e testing.
--- @param component ascii-ui.FunctionalComponent
--- @return ascii-ui.testing.E2EScreen
--- @tag ascii-ui.testing.e2e.mount()
local function mount(component)
	local bufnr = ui.mount(component)

	-- Create a Screen-like object that also has e2e methods.
	-- We need to create the fiber_root and bus ourselves since mount() does it internally.
	-- For e2e, queries operate on the actual nvim buffer, not a fiber buffer.
	local screen = setmetatable({
		_bufnr = bufnr,
	}, E2EScreen)

	return screen
end

--- Unmounts the component and closes the window.
--- Should be called after each test to clean up timers and prevent leaks.
--- @tag ascii-ui.testing.E2EScreen:unmount()
function E2EScreen:unmount()
	-- Find the window displaying this buffer
	local winnr = vim.fn.bufwinid(self._bufnr)
	if winnr and winnr ~= -1 then
		-- Close the window, which will trigger cleanup via WinClosed autocmd
		vim.api.nvim_win_close(winnr, true)
	end
end

--- @private
--- Gets lines from the actual Neovim buffer.
--- @return string[]
function E2EScreen:_get_buffer_lines()
	return vim.api.nvim_buf_get_lines(self._bufnr, 0, -1, false)
end

--- @param text string
--- @param timeout? integer milliseconds (default 1000)
--- @return boolean
function E2EScreen:bufferContains(text, timeout)
	timeout = timeout or 1000
	return vim.wait(timeout, function()
		local lines = self:_get_buffer_lines()
		local content_str = table.concat(lines, "\n")
		return content_str:find(text, 1, true) ~= nil
	end)
end

--- Waits for text to appear in the buffer.
--- @param text string
--- @param timeout? integer milliseconds (default 1000)
--- @return boolean
function E2EScreen:waitForText(text, timeout)
	timeout = timeout or 1000
	return vim.wait(timeout, function()
		return self:bufferContains(text)
	end)
end

--- Async variant of `waitForText` for use inside `async.run` tasks.
--- Polls with cooperative `async.sleep` instead of blocking `vim.wait`,
--- so it never blocks the event loop on Neovims with `vim.async`.
--- Falls back to `vim.wait`-style polling otherwise.
--- Must be called inside `async.run` on native runtimes.
--- @param text string
--- @param timeout? integer milliseconds (default 1000)
--- @return boolean found
function E2EScreen:awaitText(text, timeout)
	timeout = timeout or 1000
	local deadline = vim.uv.now() + timeout
	while vim.uv.now() < deadline do
		local lines = self:_get_buffer_lines()
		if table.concat(lines, "\n"):find(text, 1, true) ~= nil then
			return true
		end
		async.sleep(10)
	end
	local lines = self:_get_buffer_lines()
	return table.concat(lines, "\n"):find(text, 1, true) ~= nil
end

--- Asserts cursor is at the given position.
--- @param line integer
--- @param col? integer
--- @param timeout? integer milliseconds (default 400)
--- @return boolean
-- luacheck: no unused
function E2EScreen:cursorIsAt(line, col, timeout)
	timeout = timeout or 400
	return vim.wait(timeout, function()
		local cursor = Cursor.current_position()
		if col == nil then
			return cursor.line == line
		end
		return cursor.line == line and cursor.col == col
	end)
end

--- Simulates a vim keypress.
--- @param keys string
-- luacheck: no unused
function E2EScreen:press(keys)
	vim.api.nvim_feedkeys(keys, "mtx", true)
end

--- @param text string
--- @param timeout? integer milliseconds (default 1000)
--- @return boolean
function E2EScreen:hasText(text, timeout)
	return self:bufferContains(text, timeout)
end

--- @param line string
--- @return boolean
function E2EScreen:hasLine(line)
	local lines = self:_get_buffer_lines()
	for _, l in ipairs(lines) do
		if l == line then
			return true
		end
	end
	return false
end

--- @param expected_lines string[]
--- @return boolean
function E2EScreen:hasLines(expected_lines)
	local actual_lines = self:_get_buffer_lines()
	if #actual_lines ~= #expected_lines then
		return false
	end
	for i, l in ipairs(expected_lines) do
		if actual_lines[i] ~= l then
			return false
		end
	end
	return true
end

--- @return string[]
function E2EScreen:toLines()
	return self:_get_buffer_lines()
end

--- @return string
function E2EScreen:toSnapshot()
	return table.concat(self:_get_buffer_lines(), "\n")
end

return {
	mount = mount,
	E2EScreen = E2EScreen,
}
