local eq = require("tests.assertions").eq

local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local useEffect = ui.hooks.useEffect
local useState = ui.hooks.useState
local testing_e2e = require("ascii-ui.testing.e2e")

describe("useEffect dependency tracking", function()
	it("re-runs effect when dependencies change", function()
		local effect_count = 0
		local setDelay

		local App = ui.createComponent("App", function()
			local delay, _setDelay = useState(100)
			setDelay = _setDelay

			useEffect(function()
				effect_count = effect_count + 1
			end, { delay })

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Wait for initial render and effect
		vim.wait(200, function()
			return effect_count >= 1
		end)

		eq(1, effect_count, "effect should run once initially")

		-- Change the dependency
		setDelay(200)

		-- Wait for re-render and effect re-run
		vim.wait(200, function()
			return effect_count >= 2
		end)

		eq(2, effect_count, "effect should re-run when dependency changes")

		-- Clean up
		screen:unmount()
	end)

	it("re-runs effect when dependency changes from nil to value", function()
		local effect_count = 0
		local setDelay

		local App = ui.createComponent("App", function()
			local delay, _setDelay = useState(nil)
			setDelay = _setDelay

			useEffect(function()
				effect_count = effect_count + 1
			end, { delay })

			return { Paragraph({ content = "test" }) }
		end)

		local screen = testing_e2e.mount(App)

		-- Wait for initial render and effect
		vim.wait(200, function()
			return effect_count >= 1
		end)

		eq(1, effect_count, "effect should run once initially")

		-- Change the dependency from nil to a value
		setDelay(600)

		-- Wait for re-render and effect re-run
		vim.wait(200, function()
			return effect_count >= 2
		end)

		eq(2, effect_count, "effect should re-run when dependency changes from nil to value")

		-- Clean up
		screen:unmount()
	end)
end)
