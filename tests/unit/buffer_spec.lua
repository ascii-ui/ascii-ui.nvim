local Buffer = require("ascii-ui.buffer")
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local eq = require("tests.assertions").eq

describe("buffer", function()
	it("should be able to create a buffer", function()
		local b = Buffer.new()
		eq("table", type(b))
		eq(true, Buffer.is_buffer(b))
	end)

	it("creates buffer from array of strings", function()
		local b = Buffer.from_lines({ "1test", "2test" })
		eq({ "1test", "2test" }, b:to_lines())
	end)

	it("has the longest buffer line length as width", function()
		local longest = BufferLine.new(Segment:new("longest line"), Segment:new("ever written"))

		local b = Buffer.new(BufferLine.new(Segment:new("short")), BufferLine.new(Segment:new("longer line")), longest)

		eq(longest:len(), b:width())
	end)

	it("has the number of lines as height", function()
		local b = Buffer.new(BufferLine.new(), BufferLine.new(), BufferLine.new())
		eq(3, b:height())
	end)

	describe("find_focusable", function()
		it("should find the next focusable segment", function()
			local target_a = Segment:new("this is focusable", true)
			local target_b = Segment:new("another focusable", true)
			local target_c = Segment:new("yet another focusable", true)
			local b = Buffer.new(
				BufferLine.new(Segment:new("this is not focusable"), target_a),
				BufferLine.new(Segment:new("not focusable either"), target_b),
				BufferLine.new(),
				BufferLine.new(),
				BufferLine.new(target_c)
			)
			local next = b:iter_focusables()
			local found_a = next()
			eq(target_a, found_a)

			local found_b = next()
			eq(target_b, found_b)

			local found_c = next()
			eq(target_c, found_c)

			assert(next() == nil)
		end)

		it("finds next focusable segment from position", function()
			local target_a = Segment:new({ content = "this is focusable", is_focusable = true })
			local target_b = Segment:new("another focusable", true)
			local target_c = Segment:new("yet another focusable", true)
			local b = Buffer.new(
				Segment:new("this is not focusable"):wrap():append(target_a:wrap()),
				Segment:new("not focusable either"):wrap():append(target_b:wrap()),
				BufferLine.new(),
				Segment:new("not focusable either"):wrap():append(target_c:wrap())
			)

			eq({ found = true, pos = { line = 1, col = 21 } }, b:find_next_focusable({ line = 1, col = 1 }))
			eq({ found = true, pos = { line = 2, col = 20 } }, b:find_next_focusable({ line = 1, col = 22 }))
			eq({ found = true, pos = { line = 2, col = 20 } }, b:find_next_focusable({ line = 2, col = 1 }))
			eq({ found = true, pos = { line = 4, col = 20 } }, b:find_next_focusable({ line = 3, col = 1 }))
			eq(b:find_next_focusable(), b:find_next_focusable({ line = 1, col = 1 }))
		end)

		it("returns same input position when not found", function()
			local b = Buffer.new(
				BufferLine.new(Segment:new("this is not focusable")),
				BufferLine.new(Segment:new("not focusable either"))
			)

			eq({ found = false, pos = { line = 1, col = 10 } }, b:find_next_focusable({ line = 1, col = 10 }))
			eq({ found = false, pos = { line = 2, col = 10 } }, b:find_next_focusable({ line = 2, col = 10 }))
		end)

		describe("finds last focusable from position", function()
			local target_a = Segment:new("this is focusable", true)
			local target_b = Segment:new("another focusable", true)
			local target_c = Segment:new("yet another focusable", true)
			local other_line = Segment:new("focusable", true)
			local b = Buffer.new(
				BufferLine.new(Segment:new("this is not focusable"), target_a),
				BufferLine.new(Segment:new("not focusable either"), target_b),
				BufferLine.new(),
				BufferLine.new(),
				BufferLine.new(other_line, target_c, other_line)
			)

			it("1", function()
				eq({ found = true, pos = { line = 2, col = 20 } }, b:find_last_focusable({ line = 3, col = 1 }))
			end)

			it("2", function()
				eq({ found = true, pos = { line = 1, col = 21 } }, b:find_last_focusable({ line = 2, col = 1 }))
			end)

			it("3", function()
				eq({ found = false, pos = { line = 1, col = 0 } }, b:find_last_focusable({ line = 1, col = 0 }))
			end)

			it("4", function()
				eq({ found = true, pos = { line = 5, col = 9 } }, b:find_last_focusable({ line = 5, col = 30 }))
			end)

			local unfocusable = Segment:new({ content = "o" })
			local focusable = Segment:new({ content = "x", is_focusable = true })
			local buf = Buffer.new(BufferLine.new(focusable, unfocusable, focusable, unfocusable, focusable))

			it("5", function()
				eq({ found = true, pos = { line = 1, col = 2 } }, buf:find_last_focusable({ line = 1, col = 4 }))
			end)
		end)

		it("returns not found when there is not last focusable", function()
			local b = Buffer.new(
				BufferLine.new(Segment:new("this is not focusable")),
				BufferLine.new(Segment:new("not focusable either"))
			)

			eq({ found = false, pos = { line = 1, col = 10 } }, b:find_last_focusable({ line = 1, col = 10 }))
			eq({ found = false, pos = { line = 2, col = 10 } }, b:find_last_focusable({ line = 2, col = 10 }))
		end)

		it("finds the next colored segment and its position", function()
			local highlight = "SomeHighlight"
			local target_a = Segment:new("this is focusable", false, {}, highlight)
			local target_b = Segment:new("another focusable", true, {}, highlight)
			local target_c = Segment:new("yet another focusable", true, {}, highlight)
			local b = Buffer.new(
				BufferLine.new(Segment:new("this is not focusable"), target_a),
				BufferLine.new(Segment:new("not focusable either"), target_b),
				BufferLine.new(),
				BufferLine.new(),
				BufferLine.new(target_c)
			)
			local next = b:iter_colored_segments()
			local found_a = assert(next())
			eq(target_a, found_a.segment)
			eq({ line = 1, col = 22 }, found_a.position)

			local found_b = assert(next())
			eq(target_b, found_b.segment)
			eq({ line = 2, col = 21 }, found_b.position)

			local found_c = assert(next())
			eq(target_c, found_c.segment)
			eq({ line = 5, col = 1 }, found_c.position)

			assert(next() == nil)
		end)

		it("should find segment by id", function()
			local target = Segment:new("target segment")
			local b = Buffer.new(
				BufferLine.new(Segment:new("some segment A")),
				BufferLine.new(Segment:new("some segment B"), target),
				BufferLine.new(Segment:new("some elmenent C", true))
			)

			local found = b:find_segment_by_id(target.id)
			eq(target, found)
		end)

		it("should find segment by position", function()
			local target_a = Segment:new("target segment")
			local segment_before_target = Segment:new("some segment B")
			local b = Buffer.new(
				BufferLine.new(Segment:new("some segment A")),
				BufferLine.new(segment_before_target, target_a),
				BufferLine.new(Segment:new("some segment C"))
			)

			eq(target_a, b:find_segment_by_position({ line = 2, col = segment_before_target:len() + 1 }))
			eq(target_a, b:find_segment_by_position({ line = 2, col = segment_before_target:len() }))
		end)

		it("returns nil when not found", function()
			local b = Buffer.new(
				--
				BufferLine.new(Segment:new("some segment A")),
				BufferLine.new(Segment:new("some segment C"))
			)

			assert(b:find_segment_by_position({ line = math.huge, col = 1 }) == nil)
			assert(b:find_segment_by_position({ line = 1, col = math.huge }) == nil)
		end)
	end)
end)
