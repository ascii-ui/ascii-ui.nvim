local Buffer = require("ascii-ui.buffer")
local Window = require("ascii-ui.window")

describe("window", function()
	it("should open and close", function()
		local window = Window.new()
		window:open()

		assert(window:is_open())

		window:close()
		assert(not (window:is_open()))
	end)

	it("should show render", function()
		local window = Window.new()
		window:open()

		window:update(Buffer.from_lines({ "Hello, World!" }))

		window:close()
	end)

	-- Bug 2: close() used to call nvim_set_option_value("modifiable", true, { buf = nil })
	-- AFTER nilling self.bufnr, which targets buf=0 (current buffer) and silently makes it
	-- modifiable — corrupting any buffer that happened to be current at close time.
	it("close() should not change modifiable on the previously active buffer", function()
		-- Create a non-modifiable buffer and make it the current buffer before opening the float
		local other_buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_option_value("modifiable", false, { buf = other_buf })
		vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), other_buf)

		local window = Window.new()
		window:open() -- focus moves to the float

		window:close() -- focus returns to the window containing other_buf

		-- other_buf must still be non-modifiable (bug would set it to true)
		local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = other_buf })
		assert(not modifiable)

		-- cleanup
		vim.api.nvim_set_option_value("modifiable", true, { buf = other_buf })
		vim.api.nvim_buf_delete(other_buf, { force = true })
	end)

	-- Bug 3: update() checks is_open() synchronously, then defers work via vim.schedule.
	-- If close() is called between the is_open() check and the callback executing,
	-- self.bufnr / self.winid are nil when the callback runs. The stale callback then
	-- calls nvim_set_option_value("modifiable", …, { buf = nil }), which targets buf=0
	-- (whatever buffer is current at that moment) — the root cause of the fidget.nvim
	-- "Buffer is not modifiable" error.
	it("update() followed immediately by close() should not affect unrelated buffer modifiable state", function()
		local window = Window.new()
		window:open()

		-- Queue the vim.schedule callback (simulates a render cycle in flight)
		window:update(Buffer.from_lines({ "frame" }))

		-- Close before the scheduled callback executes (the race condition)
		window:close()

		-- Set up an unrelated non-modifiable buffer as current so that any stale
		-- { buf = nil } call inside the deferred callback would corrupt it
		local other_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_option_value("modifiable", false, { buf = other_buf })
		vim.api.nvim_set_current_buf(other_buf)

		-- Flush the event loop so the queued vim.schedule callback actually runs
		vim.wait(100, function()
			return false
		end)

		-- The unrelated buffer must be untouched (bug would set modifiable=true then false,
		-- but even the intermediate true-then-false transition is harmful in practice)
		local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = other_buf })
		assert(not modifiable)

		-- cleanup
		vim.api.nvim_buf_delete(other_buf, { force = true })
	end)
end)
