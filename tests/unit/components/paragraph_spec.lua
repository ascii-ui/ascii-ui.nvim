local eq = require("tests.assertions").eq

local Paragraph = require("ascii-ui.components.paragraph")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("Paragraph", function()
	it("renders simple text", function()
		local App = ui.createComponent("App", function()
			return Paragraph({ content = "hello world!" })
		end)

		eq([[hello world!]], testing.render(App):toSnapshot())
	end)

	it("renders text with new lines", function()
		local App = ui.createComponent("App", function()
			return Paragraph({ content = "hello\nworld!" })
		end)

		eq({ "hello", "world!" }, testing.render(App):toLines())
	end)
end)
