local eq = require("tests.assertions").eq

local Hightlights = require("ascii-ui.highlights")
local Select = require("ascii-ui.components.select")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("SelectComponent", function()
	it("renders segments", function()
		local option_names = { "apple", "banana", "mango" }
		local App = ui.createComponent("Test", function()
			return Select({ options = option_names })
		end)

		eq({
			"[x] apple",
			"[ ] banana",
			"[ ] mango",
		}, testing.render(App):toLines())
	end)

	it("renders selected segment with color", function()
		local option_names = { "apple", "banana", "mango" }

		local App = ui.createComponent("Test", function()
			return Select({ options = option_names })
		end)
		local screen = testing.render(App)
		local buffer = screen:_get_buffer()
		local selected_segment = assert(buffer:find_segment_by_position({ line = 1, col = 1 })) -- the first segment is selected

		eq(Hightlights.SELECTION, selected_segment.highlight)
		eq(nil, buffer:find_segment_by_position({ line = 2, col = 1 }).highlight)
		eq(nil, buffer:find_segment_by_position({ line = 3, col = 1 }).highlight)

		local second_selected_segment = assert(buffer:find_segment_by_position({ line = 2, col = 1 }))

		second_selected_segment.interactions["SELECT"]()

		-- Re-renderiza para reflejar el nuevo estado
		screen:_rerender()
		local new_buffer = screen:_get_buffer()

		local newly_selected = assert(new_buffer:find_segment_by_position({ line = 2, col = 1 }))
		eq(Hightlights.SELECTION, newly_selected.highlight)
	end)

	it("uses the user defined function on select", function()
		local option_names = { "apple", "banana", "mango" }
		local user_received_selected_option
		local user_defined_on_select_fun = function(selected_segment)
			print("selected  " .. selected_segment)
			user_received_selected_option = selected_segment
		end

		local App = ui.createComponent("Test", function()
			return Select({ options = option_names, on_select = user_defined_on_select_fun })
		end)
		local screen = testing.render(App)
		local buffer = screen:_get_buffer()

		local selected_segment = assert(buffer:find_segment_by_position({ line = 1, col = 1 })) -- the first segment is selected

		selected_segment.interactions["SELECT"]()
		eq("apple", user_received_selected_option)
	end)

	it("can have a title", function()
		local option_names = { "apple", "banana", "mango" }
		local title = "Select a fruit:"

		local App = ui.createComponent("Test", function()
			return Select({ options = option_names, title = title })
		end)

		local buffer = testing.render(App):_get_buffer()
		eq({
			"Select a fruit:",
			"[x] apple",
			"[ ] banana",
			"[ ] mango",
		}, buffer:to_lines())
	end)
end)
