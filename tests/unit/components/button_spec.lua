local eq = require("tests.assertions").eq

local Button = require("ascii-ui.components.button")
local highlights = require("ascii-ui.highlights")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("Button", function()
	it("functional", function()
		local App = ui.createComponent("App", function()
			return Button({ label = "Send" })
		end)

		local screen = testing.render(App)
		local buffer = screen:_get_buffer()

		eq([[Send]], buffer:to_string())
		eq(highlights.BUTTON, buffer.lines[1].segments[1].highlight)
	end)
end)
