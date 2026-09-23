local eq = require("tests.assertions").eq
local Segment = require("ascii-ui.buffer.segment")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")
local useReducer = require("ascii-ui.hooks.use_reducer")

describe("useReducer", function()
	it("inicializa y despacha acciones correctamente", function()
		local function reducer(s, a)
			return s + (a == "inc" and 1 or -1)
		end

		local value, dispatch
		local C = ui.createComponent("C", function()
			return function()
				value, dispatch = useReducer(reducer, 5)
				return { Segment:new({ content = tostring(value) }):wrap() }
			end
		end)

		local screen = testing.render(C)
		eq({ "5" }, screen:toLines())

		-- dispatch via closure
		dispatch("inc")
		screen:_rerender()
		eq({ "6" }, screen:toLines())

		dispatch("dec")
		screen:_rerender()
		eq({ "5" }, screen:toLines())
	end)
end)
