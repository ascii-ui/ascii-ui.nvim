local ui = require("ascii-ui")
local eq = require("tests.assertions").eq

describe("ui.map", function()
	local MyComponent = ui.createComponent("MyComponent", function(props)
		return {
			ui.blocks.Segment({ content = "Item: " .. props.item }):wrap(),
		}
	end, { item = "string" })

	it("maps items into components", function()
		local items = { "apple", "banana", "cherry" }

		eq(
			{
				MyComponent({ item = "apple1" }),
				MyComponent({ item = "banana2" }),
				MyComponent({ item = "cherry3" }),
			},
			ui.map(items, function(item, i)
				return MyComponent({ item = item .. i })
			end)
		)
	end)
end)
