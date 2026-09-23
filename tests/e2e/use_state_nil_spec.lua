local eq = require("tests.assertions").eq

local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local useState = ui.hooks.useState
local testing_e2e = require("ascii-ui.testing.e2e")

describe("useState with nil values", function()
	it("preserves nil state across re-renders", function()
		local set_state
		local render_count = 0

		local App = ui.createComponent("App", function()
			render_count = render_count + 1
			local state, _set_state = useState(100)
			set_state = _set_state

			return { Paragraph({ content = "state=" .. tostring(state) }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Wait for initial render
		vim.wait(100)
		eq(1, render_count)
		assert(screen:hasText("state=100", 100))

		-- Set state to nil
		set_state(nil)

		-- Wait for re-render
		vim.wait(200)
		eq(2, render_count)
		assert(screen:hasText("state=nil", 100), "State should be nil, not re-initialized to 100")

		screen:unmount()
	end)
end)
