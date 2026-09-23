local props_are_equal = require("ascii-ui.utils.props_are_equal")

local eq = require("tests.assertions").eq

describe("props_are_equal function", function()
	it("not equals when differing on functions", function()
		local props_a = {
			some = function() end,
		}
		local props_b = {
			some = function() end,
		}
		local result = props_are_equal(props_a, props_b)

		eq(false, result)
	end)

	it("equals when differing on inner tables", function()
		local props_a = {
			some = {},
		}
		local props_b = {
			some = {},
		}
		local result = props_are_equal(props_a, props_b)

		eq(true, result)
	end)
end)
