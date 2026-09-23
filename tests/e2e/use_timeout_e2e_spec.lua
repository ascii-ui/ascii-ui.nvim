local eq = require("tests.assertions").eq

local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local useTimeout = ui.hooks.useTimeout
local testing_e2e = require("ascii-ui.testing.e2e")

describe("useTimeout", function()
	it("cleans up timers on unmount", function()
		local callback_called = false

		local App = ui.createComponent("App", function()
			useTimeout(function()
				callback_called = true
			end, 100)

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Unmount immediately (before the 100ms timer fires)
		screen:unmount()

		-- Wait longer than the timer delay
		vim.wait(200, function()
			return false
		end)

		-- The callback should NOT have been called because the timer was cancelled
		assert(not callback_called)
	end)

	it("fires callback when not unmounted", function()
		local callback_called = false

		local App = ui.createComponent("App", function()
			useTimeout(function()
				callback_called = true
			end, 50)

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Wait for the timer to fire
		vim.wait(200, function()
			return callback_called
		end)

		assert(callback_called)

		-- Clean up
		screen:unmount()
	end)

	it("cleans up useInterval timers on unmount", function()
		local useInterval = ui.hooks.useInterval
		local call_count = 0

		local App = ui.createComponent("App", function()
			useInterval(function()
				call_count = call_count + 1
			end, 30)

			return { Paragraph({ content = "interval test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Let it fire a couple times
		vim.wait(100, function()
			return call_count >= 2
		end)

		local count_before_unmount = call_count
		assert(count_before_unmount >= 2, "interval should have fired at least twice")

		-- Unmount
		screen:unmount()

		-- Wait and verify no more calls happen
		vim.wait(150, function()
			return false
		end)

		eq(count_before_unmount, call_count)
	end)
end)
