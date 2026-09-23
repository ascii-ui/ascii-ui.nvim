local testing_e2e = require("ascii-ui.testing.e2e")
local ui = require("ascii-ui")
local Input = ui.components.Input

describe("Input E2E", function()
	it("renders with initial value", function()
		local screen = testing_e2e.mount(ui.createComponent("App", function()
			return Input({ initial_value = "hello" })
		end))

		assert(screen:waitForText("hello", 2000))
		screen:unmount()
	end)

	it("renders placeholder when empty", function()
		local screen = testing_e2e.mount(ui.createComponent("App", function()
			return Input({ placeholder = "Type here..." })
		end))

		assert(screen:waitForText("Type here...", 2000))
		screen:unmount()
	end)

	it("masks password with asterisks", function()
		local screen = testing_e2e.mount(ui.createComponent("App", function()
			return Input({ value = "secret", password = true })
		end))

		assert(screen:waitForText("******", 2000))
		screen:unmount()
	end)
end)
