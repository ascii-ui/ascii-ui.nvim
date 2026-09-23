local eq = require("tests.assertions").eq

local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local useTimeout = ui.hooks.useTimeout
local useState = ui.hooks.useState
local testing_e2e = require("ascii-ui.testing.e2e")

describe("useTimeout with dynamic delays", function()
	it("starts timer when delay changes from nil to value", function()
		local callback_called = false
		local set_should_start

		local App = ui.createComponent("App", function()
			local should_start, _set_should_start = useState(false)
			set_should_start = _set_should_start

			useTimeout(function()
				callback_called = true
			end, should_start and 50 or nil)

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Initially, delay is nil, so no timer should start
		vim.wait(100, function()
			return false
		end)
		assert(not callback_called, "callback should not be called when delay is nil")

		-- Change state so delay becomes 50ms
		set_should_start(true)

		-- Wait for the timer to fire
		vim.wait(200, function()
			return callback_called
		end)

		assert(callback_called, "callback should be called after delay changes to 50ms")

		-- Clean up
		screen:unmount()
	end)

	it("cancels timer when delay changes from value to nil", function()
		local callback_called = false
		local set_should_start

		local App = ui.createComponent("App", function()
			local should_start, _set_should_start = useState(true)
			set_should_start = _set_should_start

			useTimeout(function()
				callback_called = true
			end, should_start and 100 or nil)

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Immediately change state so delay becomes nil (before timer fires)
		vim.wait(20, function()
			return false
		end)
		set_should_start(false)

		-- Wait longer than the original timer delay
		vim.wait(200, function()
			return false
		end)

		-- The callback should NOT have been called because the timer was cancelled
		assert(not callback_called, "callback should not be called after delay changes to nil")

		-- Clean up
		screen:unmount()
	end)

	it("restarts timer when delay value changes", function()
		local callback_count = 0
		local set_delay

		local App = ui.createComponent("App", function()
			local delay, _set_delay = useState(100)
			set_delay = _set_delay

			useTimeout(function()
				callback_count = callback_count + 1
			end, delay)

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Wait for first timer to fire
		vim.wait(200, function()
			return callback_count >= 1
		end)
		eq(1, callback_count, "callback should be called once after first delay")

		-- Change delay to a different value
		set_delay(50)

		-- Wait for second timer to fire
		vim.wait(200, function()
			return callback_count >= 2
		end)
		eq(2, callback_count, "callback should be called again after delay changes")

		-- Clean up
		screen:unmount()
	end)
end)
