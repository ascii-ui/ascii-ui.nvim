local memoize = require("ascii-ui.utils.memoize")

local eq = require("tests.assertions").eq

describe("util.memoize", function()
	it("returns the same closure if the dependants are equal", function()
		local invocations_a = 0
		local dependants = { key = "value" }

		local result_fn_a = memoize(function()
			invocations_a = invocations_a + 1
		end, dependants)

		result_fn_a()
		result_fn_a()

		result_fn_a()
		result_fn_a()
		result_fn_a()

		eq(1, invocations_a, "Function should be called only once with the same dependants")
	end)
end)
