local Bufferline = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local testing_e2e = require("ascii-ui.testing.e2e")
local ui = require("ascii-ui")

describe("Focusable", function()
	it("when user moves cursor jumps to focusables (UP and DOWN)", function()
		local non_focusable_line = Segment:new({ content = "Not focusable" }):wrap()
		local focusable_line = Segment:new({ content = "Focusable", is_focusable = true }):wrap()
		local App = ui.createComponent("App", function()
			return {

				Segment:new({ content = "Not focusable" }):wrap(),
				Segment:new({ content = "Focusable", is_focusable = true }):wrap(),
				non_focusable_line:append(focusable_line),
				Segment:new({ content = "Not focusable" }):wrap(),
				Segment:new({ content = "Focusable", is_focusable = true }):wrap(),
				Segment:new({ content = "Not focusable" }):wrap(),
			}
		end)

		local screen = testing_e2e.mount(App)

		assert(screen:waitForText("Focusable"))
		assert(screen:cursorIsAt(1, 0))

		screen:press("j")
		assert(screen:cursorIsAt(2, 0))

		screen:press("j")
		assert(screen:cursorIsAt(3, 13))

		screen:press("j")
		assert(screen:cursorIsAt(5, 0))

		screen:press("k")
		assert(screen:cursorIsAt(3, 13))

		screen:press("k")
		assert(screen:cursorIsAt(2, 0))

		screen:press("k")
		assert(screen:cursorIsAt(2, 0))
	end)

	it("when user moves cursor jumps to focusables (LEFT and RIGHT)", function()
		local unfocusable = Segment:new({ content = "o" })
		local focusable = Segment:new({ content = "x", is_focusable = true })
		local App = ui.createComponent("App", function()
			return {
				Bufferline.new(focusable, unfocusable, focusable, unfocusable, focusable),
			}
		end)

		local screen = testing_e2e.mount(App)

		assert(screen:waitForText("xoxox"), "not contains")
		assert(screen:cursorIsAt(1, 0), "1,0")

		screen:press("l")
		assert(screen:cursorIsAt(1, 2), "1,2")

		screen:press("l")
		assert(screen:cursorIsAt(1, 4), "1,4")

		screen:press("h")
		assert(screen:cursorIsAt(1, 2), "1,2 back")

		screen:press("h")
		assert(screen:cursorIsAt(1, 0), "1,0 back")
	end)
end)
