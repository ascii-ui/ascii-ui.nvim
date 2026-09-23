local eq = require("tests.assertions").eq

local Segment = require("ascii-ui.buffer.segment")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

local Row = require("ascii-ui.layout.row")

describe("Row", function()
	local DummyComponent = ui.createComponent("DummyComponent", function(props)
		props = props or {}

		return function()
			return {
				Segment:new(props.content):wrap(),
				Segment:new(props.content):wrap(),
				Segment:new("smol txt"):wrap(),
			}
		end
	end, { content = "string" })

	it("should render components in a row", function()
		local App = ui.createComponent("DummyApp", function()
			return Row(
				DummyComponent({ content = "component 1" }),
				DummyComponent({ content = "component 2" }),
				DummyComponent({ content = "component 3" })
			)
		end)

		eq({
			"component 1 component 2 component 3",
			"component 1 component 2 component 3",
			"smol txt    smol txt    smol txt",
		}, testing.render(App):toLines())
	end)

	local AnotherComponent = ui.createComponent("DummyComponent", function(props)
		props = props or {}

		return function()
			return vim.iter(vim.fn.range(1, props.times))
				:map(function()
					return Segment:new(props.content):wrap()
				end)
				:totable()
		end
	end, { content = "string", times = "number" })

	it("should render components respecting the empty space on the left", function()
		local App = ui.createComponent("DummyApp", function()
			return Row(
				AnotherComponent({ content = "component 1", times = 1 }),
				AnotherComponent({ content = "component 2", times = 2 }),
				AnotherComponent({ content = "component 3", times = 3 })
			)
		end)

		eq({
			"component 1 component 2 component 3",
			"            component 2 component 3",
			"                        component 3",
		}, testing.render(App):toLines())
	end)
end)
