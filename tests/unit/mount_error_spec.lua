local eq = require("tests.assertions").eq

local error_handler = require("ascii-ui.utils.error_handler")
local fiber = require("ascii-ui.fiber")
local ui = require("ascii-ui")

describe("mount-level error handling", function()
	describe("component returns wrong type", function()
		it("produces informative error when component returns string instead of table", function()
			local Broken = ui.createComponent("BrokenReturn", function()
				return "not a table"
			end, {})

			local ok, err = pcall(fiber.render, Broken)

			assert(not ok)
			assert(err:find("BrokenReturn"), "error should mention component name")
			assert(err:find("expected.*list") or err:find("FiberNode"), "error should mention expected type")
		end)

		it("produces informative error when component returns nil", function()
			local Broken = ui.createComponent("BrokenNil", function()
				return nil
			end, {})

			local ok, err = pcall(fiber.render, Broken)

			assert(not ok)
			assert(err:find("BrokenNil"), "error should mention component name")
		end)

		it("produces informative error when component returns non-FiberNode table", function()
			local Broken = ui.createComponent("BrokenTable", function()
				return { "not", "fibers" }
			end, {})

			local ok, err = pcall(fiber.render, Broken)

			assert(not ok)
			assert(err:find("BrokenTable"), "error should mention component name")
		end)
	end)

	describe("component function error", function()
		it("includes component path when component throws during render", function()
			local Inner = ui.createComponent("Inner", function()
				error("inner error")
			end, {})

			local Outer = ui.createComponent("Outer", function()
				return { Inner() }
			end, {})

			local ok, err = pcall(fiber.render, Outer)

			assert(not ok)
			assert(err:find("Outer"), "error should mention Outer")
			assert(err:find("Inner"), "error should mention Inner")
			assert(err:find("inner error"), "error should contain original message")
		end)

		it("uses error_handler format for component errors", function()
			local Broken = ui.createComponent("BrokenComp", function()
				error("component failed")
			end, {})

			local ok, err = pcall(fiber.render, Broken)

			assert(not ok)
			-- Should use the new error format
			assert(err:find("%[render%]") or err:find("component error"), "error should use new format")
			assert(err:find("BrokenComp"), "error should mention component name")
		end)
	end)

	describe("hook errors", function()
		it("includes component context when hook fails", function()
			local Broken = ui.createComponent("BrokenHook", function()
				-- Simulate a hook error by calling a hook-like function that errors
				error("hook error in render")
			end, {})

			local ok, err = pcall(fiber.render, Broken)

			assert(not ok)
			assert(err:find("BrokenHook"), "error should mention component name")
			assert(err:find("hook error"), "error should contain hook error message")
		end)
	end)

	describe("effect errors", function()
		it("includes component context when effect fails", function()
			local FiberNode = require("ascii-ui.fibernode")
			local node = FiberNode.new({
				type = "EffectComp",
				pendingEffects = {
					function()
						error("effect failed")
					end,
				},
			})

			local ok, err = pcall(function()
				node:run_pending()
			end)

			assert(not ok)
			assert(err:find("EffectComp"), "error should mention component name")
			assert(err:find("effect failed"), "error should contain effect error message")
			-- Should use new error format
			assert(err:find("%[effect%]") or err:find("effect error"), "error should use new format")
		end)
	end)

	describe("error display", function()
		it("can convert error to displayable lines", function()
			local err = error_handler.create_error("render", "Root > App", "test error")
			local lines = error_handler.render_error_to_lines(err)

			eq("table", type(lines))
			assert(#lines > 0)

			-- All lines should be strings
			for _, line in ipairs(lines) do
				eq("string", type(line))
			end
		end)

		it("error display includes all necessary information", function()
			local err = error_handler.create_error("render", "Root > App > MenuItem", "expected list, got string")
			local lines = error_handler.render_error_to_lines(err)
			local display = table.concat(lines, "\n")

			assert(display:find("RENDER ERROR"))
			assert(display:find("render"))
			assert(display:find("Root > App > MenuItem"))
			assert(display:find("expected list, got string"))
			assert(display:find("Hint"))
		end)
	end)
end)
