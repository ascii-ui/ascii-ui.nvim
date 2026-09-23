local eq = require("tests.assertions").eq

local Input = require("ascii-ui.components.input")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("Input", function()
	it("renders", function()
		eq("", testing.render(Input):toSnapshot())
	end)

	it("renders with initial value", function()
		local initial_value = "hello world!"
		local App = ui.createComponent("App", function()
			return Input({ value = initial_value })
		end)

		eq(initial_value, testing.render(App):toSnapshot())
	end)

	it("renders with initial_value prop", function()
		local App = ui.createComponent("App", function()
			return Input({ initial_value = "initial text" })
		end)

		eq("initial text", testing.render(App):toSnapshot())
	end)

	it("renders placeholder when empty", function()
		local App = ui.createComponent("App", function()
			return Input({ placeholder = "Enter text..." })
		end)

		eq("Enter text...", testing.render(App):toSnapshot())
	end)

	it("renders value over placeholder when value is set", function()
		local App = ui.createComponent("App", function()
			return Input({ value = "actual value", placeholder = "placeholder" })
		end)

		eq("actual value", testing.render(App):toSnapshot())
	end)

	it("masks password with asterisks", function()
		local App = ui.createComponent("App", function()
			return Input({ value = "secret", password = true })
		end)

		eq("******", testing.render(App):toSnapshot())
	end)

	it("does not mask empty password", function()
		local App = ui.createComponent("App", function()
			return Input({ value = "", password = true, placeholder = "Password" })
		end)

		eq("Password", testing.render(App):toSnapshot())
	end)

	it("has _input_callbacks on segment", function()
		local screen = testing.render(ui.createComponent("App", function()
			return Input({ value = "test" })
		end))

		local segment = screen:getFocusable()
		assert(segment._input_callbacks ~= nil)
		assert(type(segment._input_callbacks.state_setter) == "function")
	end)

	it("state_setter updates value", function()
		local screen = testing.render(ui.createComponent("App", function()
			return Input({ initial_value = "initial" })
		end))

		local segment = screen:getFocusable()
		eq("initial", screen:toSnapshot())

		-- Call state_setter to update value
		segment._input_callbacks.state_setter("updated")
		screen:_rerender()

		eq("updated", screen:toSnapshot())
	end)

	it("calls on_change callback", function()
		local change_called = false
		local change_value = nil

		local screen = testing.render(ui.createComponent("App", function()
			return Input({
				initial_value = "test",
				on_change = function(val)
					change_called = true
					change_value = val
				end,
			})
		end))

		local segment = screen:getFocusable()
		assert(type(segment._input_callbacks.on_change) == "function")

		-- Call on_change
		segment._input_callbacks.on_change("new value")
		assert(change_called)
		eq("new value", change_value)
	end)

	it("calls on_submit callback", function()
		local submit_called = false
		local submit_value = nil

		local screen = testing.render(ui.createComponent("App", function()
			return Input({
				initial_value = "test",
				on_submit = function(val)
					submit_called = true
					submit_value = val
				end,
			})
		end))

		local segment = screen:getFocusable()
		assert(type(segment._input_callbacks.on_submit) == "function")

		-- Call on_submit
		segment._input_callbacks.on_submit("submitted value")
		assert(submit_called)
		eq("submitted value", submit_value)
	end)

	it("calls on_blur callback", function()
		local blur_called = false
		local blur_value = nil

		local screen = testing.render(ui.createComponent("App", function()
			return Input({
				initial_value = "test",
				on_blur = function(val)
					blur_called = true
					blur_value = val
				end,
			})
		end))

		local segment = screen:getFocusable()
		assert(type(segment._input_callbacks.on_blur) == "function")

		-- Call on_blur
		segment._input_callbacks.on_blur("blurred value")
		assert(blur_called)
		eq("blurred value", blur_value)
	end)

	it("controlled input syncs with parent state", function()
		local parent_value = "parent value"

		local App = ui.createComponent("App", function()
			return Input({ value = parent_value })
		end)

		local screen = testing.render(App)
		eq("parent value", screen:toSnapshot())
	end)

	it("uncontrolled input maintains internal state", function()
		local screen = testing.render(ui.createComponent("App", function()
			return Input({ initial_value = "internal" })
		end))

		eq("internal", screen:toSnapshot())

		-- Update via state_setter (simulating user input)
		local segment = screen:getFocusable()
		segment._input_callbacks.state_setter("updated internally")
		screen:_rerender()

		eq("updated internally", screen:toSnapshot())
	end)
end)
