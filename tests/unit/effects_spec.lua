local eq = require("tests.assertions").eq

local Effect = require("ascii-ui.effect")

describe("Effect", function()
	it("can create an effect", function()
		local effect = Effect({
			fn = function()
				return function()
					-- cleanup function
				end
			end,
		})

		eq(effect.get_status(), "INITIAL")
	end)

	it("can run an effect", function()
		local invoked = false
		local effect = Effect({
			fn = function()
				invoked = true
				return function() end
			end,
		})

		effect.run()

		eq(effect.get_status(), "MOUNTED")
		eq(true, invoked)
	end)

	it("can run an cleanup after an effect", function()
		local invoked = {
			effect = false,
			cleanup = false,
		}
		local effect = Effect({
			fn = function()
				invoked.effect = true
				return function()
					invoked.cleanup = true
				end
			end,
		})

		effect.run()
		effect.cleanup()

		eq(effect.get_status(), "CLEANED_UP")
		eq(true, invoked.cleanup)
	end)

	describe("can determine whether it should be replaced or not based on the dependencies diff", function()
		it("dependencies is nil", function()
			local dependencies_a = nil
			local dependencies_b = nil
			local effect = Effect({
				fn = function()
					return function() end
				end,
				dependencies = dependencies_a,
			})

			local actual, reasons = effect.should_be_replaced(dependencies_b)
			eq(true, actual)
			eq({ "NIL_DEPENDENCIES" }, reasons)
		end)

		it("last dependencies was nil", function()
			local dependencies_a = nil
			local dependencies_b = {}
			local effect = Effect({
				fn = function()
					return function() end
				end,
				dependencies = dependencies_a,
			})

			local actual, reasons = effect.should_be_replaced(dependencies_b)
			eq(true, actual)
			eq({ "NIL_DEPENDENCIES", "DIFFERENT_COUNT_OF_VALUES" }, reasons)
		end)

		it("different values", function()
			local dependencies_a = { 1, 2, 3 }
			local dependencies_b = { 1, 2, 4 }
			local effect = Effect({
				fn = function()
					return function() end
				end,
				dependencies = dependencies_a,
			})

			local actual, reasons = effect.should_be_replaced(dependencies_b)
			eq(true, actual)
			eq({ "DIFFERENT_VALUES" }, reasons)
		end)

		it("different count of dependencies", function()
			local dependencies_a = { 1, 2, 3 }
			local dependencies_b = { 1, 2 }
			local effect = Effect({
				fn = function()
					return function() end
				end,
				dependencies = dependencies_a,
			})

			local actual, reasons = effect.should_be_replaced(dependencies_b)
			eq(true, actual)
			eq({ "DIFFERENT_COUNT_OF_VALUES" }, reasons)
		end)
	end)
end)
