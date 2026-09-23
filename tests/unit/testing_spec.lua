local eq = require("tests.assertions").eq
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")
local Select = ui.components.Select
local Paragraph = ui.components.Paragraph

describe("testing library", function()
	describe("render()", function()
		it("renders a component and returns a screen", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello world" })
			end)
			local screen = testing.render(App)
			assert(screen ~= nil)
		end)
	end)

	describe("queries", function()
		it("getByText finds segment by text", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello world" })
			end)
			local screen = testing.render(App)
			local segment = screen:getByText("hello")
			assert(segment ~= nil)
			eq("hello world", segment.content)
		end)

		it("getByText errors when text not found", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello" })
			end)
			local screen = testing.render(App)
			MiniTest.expect.error(function()
				screen:getByText("missing")
			end, "Text not found: missing")
		end)

		it("queryByText returns nil when not found", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello" })
			end)
			local screen = testing.render(App)
			local result = screen:queryByText("missing")
			assert(result == nil)
		end)

		it("getAllByText finds all matching segments", function()
			local App = ui.createComponent("Test", function()
				return {
					Paragraph({ content = "apple" }),
					Paragraph({ content = "apple pie" }),
					Paragraph({ content = "banana" }),
				}
			end)
			local screen = testing.render(App)
			local results = screen:getAllByText("apple")
			eq(2, #results)
		end)

		it("getFocusable returns first focusable segment", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b", "c" } })
			end)
			local screen = testing.render(App)
			local focusable = screen:getFocusable()
			assert(focusable ~= nil)
		end)

		it("getAllFocusable returns all focusable segments", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b", "c" } })
			end)
			local screen = testing.render(App)
			local focusables = screen:getAllFocusable()
			eq(3, #focusables)
		end)
	end)

	describe("assertions", function()
		it("hasText checks if buffer contains text", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello world" })
			end)
			local screen = testing.render(App)
			assert(screen:hasText("hello"))
			assert(not (screen:hasText("missing")))
		end)

		it("hasLine checks for exact line match", function()
			local App = ui.createComponent("Test", function()
				return Paragraph({ content = "hello" })
			end)
			local screen = testing.render(App)
			assert(screen:hasLine("hello"))
			assert(not (screen:hasLine("hello world")))
		end)

		it("hasLines checks full buffer match", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b" } })
			end)
			local screen = testing.render(App)
			assert(screen:hasLines({ "[x] a", "[ ] b" }))
			assert(not (screen:hasLines({ "[ ] a", "[ ] b" })))
		end)

		it("hasFocusable checks for focusable with text", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "apple", "banana" } })
			end)
			local screen = testing.render(App)
			assert(screen:hasFocusable("apple"))
		end)
	end)

	describe("interactions", function()
		it("select triggers SELECT interaction and rerenders", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b", "c" } })
			end)
			local screen = testing.render(App)
			assert(screen:hasLines({ "[x] a", "[ ] b", "[ ] c" }))

			screen:select("b")
			assert(screen:hasLines({ "[ ] a", "[x] b", "[ ] c" }))
		end)

		it("trigger triggers custom interaction", function()
			local Segment = require("ascii-ui.buffer.segment")
			local interaction_type = require("ascii-ui.interaction_type")
			local clicked = false
			local App = ui.createComponent("Test", function()
				return {
					Segment:new({
						content = "click me",
						is_focusable = true,
						interactions = {
							[interaction_type.SELECT] = function()
								clicked = true
							end,
						},
					}):wrap(),
				}
			end)
			local screen = testing.render(App)
			screen:trigger("click me", interaction_type.SELECT)
			assert(clicked)
		end)
	end)

	describe("buffer inspection", function()
		it("toLines returns buffer lines", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b" } })
			end)
			local screen = testing.render(App)
			local lines = screen:toLines()
			eq({ "[x] a", "[ ] b" }, lines)
		end)

		it("toSnapshot returns buffer as string", function()
			local App = ui.createComponent("Test", function()
				return Select({ options = { "a", "b" } })
			end)
			local screen = testing.render(App)
			local snapshot = screen:toSnapshot()
			eq("[x] a\n[ ] b", snapshot)
		end)
	end)
end)
