local eq = require("tests.assertions").eq
local Segment = require("ascii-ui.buffer.segment")
local ui = require("ascii-ui")

describe("useAsync", function()
	it("runs the async function after mount", function()
		local seen = {}
		local Component = ui.createComponent("C", function()
			ui.hooks.useAsync(function()
				seen[#seen + 1] = "ran"
			end, {})
			return { Segment:new({ content = "hi" }):wrap() }
		end)

		ui.mount(Component)
		vim.wait(1000, function()
			return #seen == 1
		end)
		eq({ "ran" }, seen)
	end)

	it("re-runs when dependencies change", function()
		local runs = {}
		local value, set_value
		local Component = ui.createComponent("C", function()
			value, set_value = ui.hooks.useState("a")
			ui.hooks.useAsync(function()
				runs[#runs + 1] = value
			end, { value })
			return { Segment:new({ content = value }):wrap() }
		end)

		ui.mount(Component)
		vim.wait(1000, function()
			return #runs >= 1
		end)
		set_value("b")
		vim.wait(1000, function()
			return #runs >= 2
		end)
		eq("a", runs[1])
		eq("b", runs[2])
	end)

	it("exposes async utilities through the hook task", function()
		local async = require("ascii-ui.utils.async")
		eq("function", type(async.after))
		eq("function", type(async.every))
		eq("function", type(async.run))
		eq("function", type(async.sleep))
	end)
end)
