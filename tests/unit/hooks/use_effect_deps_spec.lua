local eq = require("tests.assertions").eq
local Segment = require("ascii-ui.buffer.segment")
local ui = require("ascii-ui")
local useEffect = require("ascii-ui.hooks.use_effect")
local useState = require("ascii-ui.hooks.use_state")

describe("useEffect dependency changes", function()
	it("re-runs effect when dependency value changes", function()
		local effect_count = 0
		local set_delay

		local Component = ui.createComponent("C", function()
			local delay, _set_delay = useState(100)
			set_delay = _set_delay

			useEffect(function()
				effect_count = effect_count + 1
			end, { delay })

			return { Segment:new({ content = tostring(delay) }):wrap() }
		end)

		-- Mount the component (this triggers initial render)
		ui.mount(Component)

		-- Wait for initial effect to run
		vim.wait(100, function()
			return effect_count >= 1
		end)

		eq(1, effect_count, "effect should run once initially")

		-- Change the dependency
		set_delay(200)

		-- Wait for re-render and effect re-run
		vim.wait(100, function()
			return effect_count >= 2
		end)

		eq(2, effect_count, "effect should re-run when dependency changes")
	end)

	it("re-runs effect when dependency changes from nil to value", function()
		local effect_count = 0
		local set_delay

		local Component = ui.createComponent("C", function()
			local delay, _set_delay = useState(nil)
			set_delay = _set_delay

			useEffect(function()
				effect_count = effect_count + 1
			end, { delay })

			return { Segment:new({ content = tostring(delay) }):wrap() }
		end)

		-- Mount the component
		ui.mount(Component)

		-- Wait for initial effect to run
		vim.wait(100, function()
			return effect_count >= 1
		end)

		eq(1, effect_count, "effect should run once initially")

		-- Change the dependency from nil to a value
		set_delay(600)

		-- Wait for re-render and effect re-run
		vim.wait(100, function()
			return effect_count >= 2
		end)

		eq(2, effect_count, "effect should re-run when dependency changes from nil to value")
	end)
end)
