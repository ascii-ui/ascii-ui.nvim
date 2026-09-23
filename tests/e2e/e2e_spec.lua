local ui = require("ascii-ui")
local Select = ui.components.Select
local Paragraph = ui.components.Paragraph
local Slider = ui.components.Slider
local useState = ui.hooks.useState
local Segment = require("ascii-ui.buffer.segment")
local interaction_type = require("ascii-ui.interaction_type")
local testing_e2e = require("ascii-ui.testing.e2e")

describe("ascii-ui", function()
	it("interacts with segments of a Select component", function()
		local App = ui.createComponent("App", function()
			return Select({ options = {
				"book",
				"pencil",
				"rubber",
			} })
		end)

		local screen = testing_e2e.mount(App)

		assert(screen:waitForText("[x] book"))

		-- move down and press enter
		screen:press("j")
		local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		screen:press(enter) -- simulate pressing Enter on the button

		assert(screen:waitForText("[x] pencil"))
	end)

	describe("sliders", function()
		it("sliders slide", function()
			local App = ui.createComponent("App", function()
				return {
					--
					Slider({ title = "test-slider 1" }),
					Slider({ title = "test-slider 2" }),
				}
			end)

			local screen = testing_e2e.mount(App)
			assert(screen:waitForText("0%"))

			screen:press("j")

			screen:press("llllll")
			assert(screen:waitForText("60%"), "no encuentra 60%")

			screen:press("hhh")
			assert(screen:waitForText("30%"), "no encuentra 30%")

			screen:press("j")
			assert(screen:cursorIsAt(4), "no está en la línea 4")

			screen:press("ll")
			assert(screen:waitForText("20%"), "no encuentra 20%")

			screen:press("lll")
			assert(screen:waitForText("50%"))
		end)

		it("fiber functional", function()
			local content, setContent
			local App = ui.createComponent("App", function()
				content, setContent = useState("hola mundo")
				return Paragraph({ content = content })
			end)
			local screen = testing_e2e.mount(App)
			assert(screen:waitForText("hola mundo"))

			setContent("lemon juice")
			assert(screen:waitForText("lemon juice"))
		end)

		it("fiber functional interaction", function()
			local content, setContent
			local App = ui.createComponent("App", function()
				content, setContent = useState("hola mundo")
				return {
					Segment:new({
						content = content,
						interactions = {
							[interaction_type.CURSOR_MOVE_RIGHT] = function()
								setContent("right")
							end,
							[interaction_type.CURSOR_MOVE_LEFT] = function()
								setContent("left")
							end,
						},
					}):wrap(),
				}
			end)
			local screen = testing_e2e.mount(App)
			assert(screen:waitForText("hola mundo"))

			screen:press("l")
			assert(screen:waitForText("right"))

			screen:press("h")
			assert(screen:waitForText("left"))
		end)
	end)

	it("fiber functional interaction with inner component", function()
		local content, setContent
		local SomeComponent = ui.createComponent("SomeComponent", function()
			content, setContent = useState("hola mundo")
			return {
				Segment:new({
					content = content,
					interactions = {
						[interaction_type.CURSOR_MOVE_RIGHT] = function()
							setContent("right")
						end,
						[interaction_type.CURSOR_MOVE_LEFT] = function()
							setContent("left")
						end,
					},
				}):wrap(),
			}
		end)
		local App = ui.createComponent("App", function()
			return SomeComponent()
		end)
		local screen = testing_e2e.mount(App)
		assert(screen:waitForText("hola mundo"))

		screen:press("l")
		assert(screen:waitForText("right"))

		screen:press("h")
		assert(screen:waitForText("left"))
	end)
end)
