local eq = require("tests.assertions").eq

local Command = require("ascii-ui.commands")

describe("Command", function()
	describe("constructors", function()
		it("CloseWindow creates command with correct structure", function()
			local cmd = Command.CloseWindow({ window_id = 42 })
			eq("CLOSE_WINDOW", cmd.type)
			eq(42, cmd.window_id)
		end)

		it("MoveWindow creates command with correct structure", function()
			local pos = { line = 10, col = 20 }
			local cmd = Command.MoveWindow({ window_id = 1, position = pos })
			eq("MOVE_WINDOW", cmd.type)
			eq(1, cmd.window_id)
			eq(pos, cmd.position)
		end)

		it("CursorMove creates command with correct structure", function()
			local pos = { line = 5, col = 3 }
			local cmd = Command.CursorMove({ direction = "SOUTH", position = pos })
			eq("CURSOR_MOVE", cmd.type)
			eq("SOUTH", cmd.direction)
			eq(pos, cmd.position)
		end)

		it("Select creates command with correct structure", function()
			local pos = { line = 1, col = 0 }
			local cmd = Command.Select({ window_id = 2, position = pos })
			eq("SELECT", cmd.type)
			eq(2, cmd.window_id)
			eq(pos, cmd.position)
		end)

		it("Hover creates command with correct structure", function()
			local pos = { line = 3, col = 5 }
			local cmd = Command.Hover({ window_id = 3, position = pos })
			eq("HOVER", cmd.type)
			eq(3, cmd.window_id)
			eq(pos, cmd.position)
		end)

		it("Input creates command with correct structure", function()
			local pos = { line = 2, col = 1 }
			local cmd = Command.Input({ window_id = 4, position = pos, text = "hello" })
			eq("INPUT", cmd.type)
			eq(4, cmd.window_id)
			eq(pos, cmd.position)
			eq("hello", cmd.text)
		end)

		it("StateChange creates command with correct structure", function()
			local cmd = Command.StateChange({ prop = "count", value = 42 })
			eq("STATE_CHANGE", cmd.type)
			eq("count", cmd.prop)
			eq(42, cmd.value)
		end)

		it("Mount creates command with correct structure", function()
			local comp = function()
				return {}
			end
			local cmd = Command.Mount({ component = comp })
			eq("MOUNT", cmd.type)
			eq(comp, cmd.component)
		end)

		it("Unmount creates command with correct structure", function()
			local cmd = Command.Unmount({ window_id = 5 })
			eq("UNMOUNT", cmd.type)
			eq(5, cmd.window_id)
		end)
	end)

	describe("types", function()
		it("exposes command type constants", function()
			eq("CLOSE_WINDOW", Command.types.CLOSE_WINDOW)
			eq("MOVE_WINDOW", Command.types.MOVE_WINDOW)
			eq("CURSOR_MOVE", Command.types.CURSOR_MOVE)
			eq("SELECT", Command.types.SELECT)
			eq("HOVER", Command.types.HOVER)
			eq("INPUT", Command.types.INPUT)
			eq("STATE_CHANGE", Command.types.STATE_CHANGE)
			eq("MOUNT", Command.types.MOUNT)
			eq("UNMOUNT", Command.types.UNMOUNT)
		end)
	end)

	describe("immutability convention", function()
		it("commands are plain tables (immutability by convention)", function()
			local cmd = Command.CloseWindow({ window_id = 1 })
			eq("table", type(cmd))
			-- Commands are immutable by convention - handlers should not mutate them
			-- This test documents the convention but does not enforce it programmatically
		end)
	end)
end)
