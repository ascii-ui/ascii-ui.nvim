local fiber = require("ascii-ui.fiber")
local ui = require("ascii-ui")

describe("component error reporting", function()
	it("shows the failing component name in the error message", function()
		local Broken = ui.createComponent("Broken", function()
			error("something went wrong")
		end, {})

		local ok, err = pcall(fiber.render, Broken)

		assert(not ok)
		assert(err:find("Broken"), "error should mention the component name 'Broken'")
		assert(err:find("something went wrong"), "error should contain the original error reason")
	end)

	it("shows the full component path when a nested component fails", function()
		local Inner = ui.createComponent("Inner", function()
			error("inner broke")
		end, {})

		local Outer = ui.createComponent("Outer", function()
			return { Inner() }
		end, {})

		local ok, err = pcall(fiber.render, Outer)

		assert(not ok)
		assert(err:find("Outer"), "error should mention the outer component 'Outer'")
		assert(err:find("Inner"), "error should mention the inner component 'Inner'")
		assert(err:find("inner broke"), "error should contain the original error reason")
	end)

	it("shows a three-level deep component path", function()
		local Leaf = ui.createComponent("Leaf", function()
			error("leaf error")
		end, {})

		local Middle = ui.createComponent("Middle", function()
			return { Leaf() }
		end, {})

		local Root = ui.createComponent("Root", function()
			return { Middle() }
		end, {})

		local ok, err = pcall(fiber.render, Root)

		assert(not ok)
		assert(err:find("Root"), "error should mention Root")
		assert(err:find("Middle"), "error should mention Middle")
		assert(err:find("Leaf"), "error should mention Leaf")
		assert(err:find("leaf error"), "error should contain original reason")
	end)
end)
