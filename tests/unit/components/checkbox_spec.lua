local eq = require("tests.assertions").eq

local Checkbox = require("ascii-ui.components.checkbox")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("checkbox", function()
	it("renders", function()
		local App = ui.createComponent("App", function()
			return Checkbox({ label = "some-label" })
		end)
		eq("[ ] some-label", testing.render(App):toSnapshot())

		local App2 = ui.createComponent("App", function()
			return Checkbox({ active = true, label = "some-other-label" })
		end)
		eq("[x] some-other-label", testing.render(App2):toSnapshot())
	end)
end)
