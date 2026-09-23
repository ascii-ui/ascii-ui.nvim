local strict_throttle = require("ascii-ui.utils.strict_throttle")

local eq = require("tests.assertions").eq

describe("throttle", function()
	it("calls the function immediately on the first call", function()
		local called = false
		local func = function()
			called = true
		end
		local throttled_func = strict_throttle(func, 100)

		throttled_func()

		eq(true, called)
	end)

	it("does not call the function again within the delay", function()
		local call_count = 0
		local func = function()
			call_count = call_count + 1
		end
		local throttled_func = strict_throttle(func, 100)

		throttled_func()
		throttled_func()

		eq(1, call_count)
	end)

	it("it calls the function again after the delay with the last arguments", function()
		local call_count = 0
		local test_message = "initial message"
		local func = function(msg)
			test_message = msg
			call_count = call_count + 1
		end
		local throttled_func = strict_throttle(func, 100)

		throttled_func("first call")
		throttled_func("second call")
		throttled_func("third call")

		eq(1, call_count)
		eq("first call", test_message)

		-- Wait for the delay to pass
		vim.wait(300, function()
			return false
		end)
		eq(2, call_count)
		eq("third call", test_message)

		throttled_func("4th call")
		throttled_func("5th call")
		throttled_func("6th call")
		eq("4th call", test_message)
		eq(3, call_count)

		vim.wait(300, function()
			return false
		end)
		eq(4, call_count)
		eq("6th call", test_message)
	end)
end)
