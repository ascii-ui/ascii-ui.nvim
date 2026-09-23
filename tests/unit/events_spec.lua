local eq = require("tests.assertions").eq

local Command = require("ascii-ui.commands")
local EventBus = require("ascii-ui.events")

describe("EventBus command system", function()
	describe("dispatch and on", function()
		it("dispatch calls registered handlers for command type", function()
			local bus = EventBus.new()
			local called = false
			local received_command = nil

			bus:on("CLOSE_WINDOW", function(cmd)
				called = true
				received_command = cmd
			end)

			local cmd = Command.CloseWindow({ window_id = 42 })
			bus:dispatch(cmd)

			assert(called)
			eq(cmd, received_command)
			eq(42, received_command.window_id)
		end)

		it("dispatch calls multiple handlers for same command type", function()
			local bus = EventBus.new()
			local call_count = 0

			bus:on("SELECT", function()
				call_count = call_count + 1
			end)
			bus:on("SELECT", function()
				call_count = call_count + 1
			end)

			bus:dispatch(Command.Select({ window_id = 1, position = { line = 1, col = 0 } }))

			eq(2, call_count)
		end)

		it("dispatch does not call handlers for different command types", function()
			local bus = EventBus.new()
			local called = false

			bus:on("CLOSE_WINDOW", function()
				called = true
			end)

			bus:dispatch(Command.Select({ window_id = 1, position = { line = 1, col = 0 } }))

			assert(not called)
		end)

		it("dispatch handles no handlers gracefully", function()
			local bus = EventBus.new()
			-- Should not throw
			bus:dispatch(Command.CloseWindow({ window_id = 1 }))
		end)

		it("dispatch handles invalid command gracefully", function()
			local bus = EventBus.new()
			-- Should not throw
			bus:dispatch(nil)
			bus:dispatch({})
			bus:dispatch({ type = nil })
		end)

		it("handler errors are caught and logged", function()
			local bus = EventBus.new()
			local second_handler_called = false

			bus:on("SELECT", function()
				error("test error")
			end)
			bus:on("SELECT", function()
				second_handler_called = true
			end)

			-- Should not throw, and second handler should still be called
			bus:dispatch(Command.Select({ window_id = 1, position = { line = 1, col = 0 } }))

			assert(second_handler_called)
		end)
	end)

	describe("on validation", function()
		it("on requires non-empty string command_type", function()
			local bus = EventBus.new()
			MiniTest.expect.error(function()
				bus:on("", function() end)
			end)
			MiniTest.expect.error(function()
				bus:on(nil, function() end)
			end)
		end)

		it("on requires function handler", function()
			local bus = EventBus.new()
			MiniTest.expect.error(function()
				bus:on("SELECT", "not a function")
			end)
			MiniTest.expect.error(function()
				bus:on("SELECT", nil)
			end)
		end)
	end)

	describe("history", function()
		it("history records dispatched commands", function()
			local bus = EventBus.new()

			local cmd1 = Command.CloseWindow({ window_id = 1 })
			local cmd2 = Command.Select({ window_id = 2, position = { line = 1, col = 0 } })

			bus:dispatch(cmd1)
			bus:dispatch(cmd2)

			local history = bus:history()
			eq(2, #history)
			eq(cmd1, history[1])
			eq(cmd2, history[2])
		end)

		it("history returns a copy (not the internal array)", function()
			local bus = EventBus.new()
			bus:dispatch(Command.CloseWindow({ window_id = 1 }))

			local history1 = bus:history()
			local history2 = bus:history()

			-- `~=` checks identity: two calls must return different tables
			-- with deeply equal contents.
			assert(history1 ~= history2)
			eq(history1, history2)
		end)

		it("history is empty initially", function()
			local bus = EventBus.new()
			local history = bus:history()
			eq(0, #history)
		end)
	end)

	describe("backward compatibility", function()
		it("listen and trigger still work", function()
			local bus = EventBus.new()
			local called = false

			bus:listen("state_change", function()
				called = true
			end)

			bus:trigger("state_change")

			assert(called)
		end)

		it("clear removes all listeners including command handlers", function()
			local bus = EventBus.new()
			local command_called = false
			local event_called = false

			bus:on("SELECT", function()
				command_called = true
			end)
			bus:listen("state_change", function()
				event_called = true
			end)

			bus:clear()

			bus:dispatch(Command.Select({ window_id = 1, position = { line = 1, col = 0 } }))
			bus:trigger("state_change")

			assert(not command_called)
			assert(not event_called)
		end)

		it("clear resets history", function()
			local bus = EventBus.new()
			bus:dispatch(Command.CloseWindow({ window_id = 1 }))
			eq(1, #bus:history())

			bus:clear()
			eq(0, #bus:history())
		end)
	end)
end)
