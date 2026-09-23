local eq = require("tests.assertions").eq
local Segment = require("ascii-ui.buffer.segment")
local ui = require("ascii-ui")
local useEffect = require("ascii-ui.hooks.use_effect")

describe("useEffect", function()
	it("gets executed just once when no dependencies", function()
		local log = {}
		local use_state_log = {}
		local value, set_value
		local Component = ui.createComponent("C", function()
			value, set_value = ui.hooks.useState(0)
			use_state_log[#use_state_log + 1] = "useState called with value: " .. tostring(value)
			useEffect(function()
				log[#log + 1] = "useEffect called"
			end, {})
			return { Segment:new({ content = tostring(value) }):wrap() }
		end)

		ui.mount(Component)

		set_value(1)
		set_value(2)
		set_value(3)
		vim.wait(100, function()
			return #use_state_log > 1
		end)

		eq({ "useEffect called" }, log)
	end)

	it("gets executed as much as dependencies change", function()
		local log = {}
		local use_state_log = {}
		local value, set_value
		local another_value, set_another_value
		local Component = ui.createComponent("C", function()
			value, set_value = ui.hooks.useState(0)
			another_value, set_another_value = ui.hooks.useState(0)
			use_state_log[#use_state_log + 1] = "useState called with value: " .. tostring(value)
			useEffect(function()
				log[#log + 1] = "useEffect called"
			end, { value })
			return { Segment:new({ content = tostring(value) .. tostring(another_value) }):wrap() }
		end)

		ui.mount(Component)

		set_value(1)
		set_value(2)
		set_value(3)
		set_another_value(1)
		set_another_value(2)
		set_another_value(3)
		set_another_value(4)
		set_another_value(5)
		vim.wait(100, function()
			return false
		end)

		eq(3 + 1, #log)
	end)

	it("gets executed every render when there is nil dependencies", function()
		local log = {}
		local use_state_log = {}
		local value, set_value
		local another_value, set_another_value
		local Component = ui.createComponent("C", function()
			value, set_value = ui.hooks.useState(0)
			another_value, set_another_value = ui.hooks.useState(0)
			use_state_log[#use_state_log + 1] = "useState called with value: " .. tostring(value)
			useEffect(function()
				log[#log + 1] = "useEffect called"
			end)
			return { Segment:new({ content = tostring(value) .. tostring(another_value) }):wrap() }
		end)

		ui.mount(Component)

		set_value(1)
		set_value(2)
		set_value(3)
		set_another_value(1)
		set_another_value(2)
		set_another_value(3)
		set_another_value(4)
		set_another_value(5)
		vim.wait(100, function()
			return false
		end)

		eq(8 + 1, #log)
	end)

	it("gets executed right when has state change inside", function()
		local log = {}
		local use_state_log = {}
		local value, set_value
		local message, set_message
		local Component = ui.createComponent("C", function()
			value, set_value = ui.hooks.useState(0)
			message, set_message = ui.hooks.useState("initial message")
			use_state_log[#use_state_log + 1] = "useState called with value: " .. tostring(value)
			useEffect(function()
				log[#log + 1] = "useEffect called"
				if #log > 10 then
					error(debug.traceback("log exceeded the max: "))
				end
				set_message("useEffect called with value: " .. tostring(value))
			end, { value })
			return { Segment:new({ content = message }):wrap() }
		end)

		ui.mount(Component)

		set_value(1)
		set_value(2)
		set_value(3)
		vim.wait(100, function()
			return false
		end)

		-- TODO: this is tricky and will revise later
		-- expected to run 3 times
		-- but twice because of state change inside
		-- plus one for initial render
		eq(3 * 2 + 2, #log)
	end)
end)
