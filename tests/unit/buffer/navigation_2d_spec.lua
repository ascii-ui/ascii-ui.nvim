local eq = require("tests.assertions").eq

local Buffer = require("ascii-ui.buffer.buffer")
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")

describe("2D focus navigation", function()
	-- Helper: build a 2x2 grid of focusable segments
	-- Line 1: [A]  [B]   → A at col 0, B at col 3
	-- Line 2: [C]  [D]   → C at col 0, D at col 3
	local function make_grid()
		local buttonA = Segment:new({ content = "A", is_focusable = true })
		local buttonB = Segment:new({ content = "B", is_focusable = true })
		local buttonC = Segment:new({ content = "C", is_focusable = true })
		local buttonD = Segment:new({ content = "D", is_focusable = true })
		local spacer = Segment:new({ content = "  " })

		local line1 = BufferLine.new(buttonA, spacer, buttonB)
		local line2 = BufferLine.new(buttonC, spacer, buttonD)
		local buffer = Buffer.new(line1, line2)

		return buffer, { A = buttonA, B = buttonB, C = buttonC, D = buttonD }
	end

	describe("find_focusable_above (k key)", function()
		it("finds focusable directly above when pressing 'k'", function()
			local buffer = make_grid()

			-- When focused on Button D (line 2, col 3)
			-- Pressing "k" should go to Button B (line 1, col 3)
			-- NOT Button C (line 2, col 0) which is previous in linear order
			local result = buffer:find_focusable_above({ line = 2, col = 3 })

			eq(true, result.found)
			eq(1, result.pos.line)
			eq(3, result.pos.col)
		end)

		it("finds focusable above from left column", function()
			local buffer = make_grid()

			-- When focused on Button C (line 2, col 0)
			-- Pressing "k" should go to Button A (line 1, col 0)
			local result = buffer:find_focusable_above({ line = 2, col = 0 })

			eq(true, result.found)
			eq(1, result.pos.line)
			eq(0, result.pos.col)
		end)

		it("returns not found when no focusable above", function()
			local buffer = make_grid()

			-- When focused on Button A (line 1, col 0) — top row
			-- Pressing "k" should find nothing
			local result = buffer:find_focusable_above({ line = 1, col = 0 })

			eq(false, result.found)
		end)
	end)

	describe("find_focusable_below (j key)", function()
		it("finds focusable directly below when pressing 'j'", function()
			local buffer = make_grid()

			-- When focused on Button A (line 1, col 0)
			-- Pressing "j" should go to Button C (line 2, col 0)
			local result = buffer:find_focusable_below({ line = 1, col = 0 })

			eq(true, result.found)
			eq(2, result.pos.line)
			eq(0, result.pos.col)
		end)

		it("finds focusable below from right column", function()
			local buffer = make_grid()

			-- When focused on Button B (line 1, col 3)
			-- Pressing "j" should go to Button D (line 2, col 3)
			local result = buffer:find_focusable_below({ line = 1, col = 3 })

			eq(true, result.found)
			eq(2, result.pos.line)
			eq(3, result.pos.col)
		end)

		it("returns not found when no focusable below", function()
			local buffer = make_grid()

			-- When focused on Button D (line 2, col 3) — bottom row
			-- Pressing "j" should find nothing
			local result = buffer:find_focusable_below({ line = 2, col = 3 })

			eq(false, result.found)
		end)
	end)

	describe("closest column matching", function()
		it("finds closest column when exact column not available above", function()
			-- Irregular layout:
			-- Line 1: [A]          [B]   → A at col 0, B at col 11
			-- Line 2:       [C]          → C at col 6
			local buttonA = Segment:new({ content = "A", is_focusable = true })
			local buttonB = Segment:new({ content = "B", is_focusable = true })
			local buttonC = Segment:new({ content = "C", is_focusable = true })

			local line1 = BufferLine.new(buttonA, Segment:new({ content = "          " }), buttonB)
			local line2 = BufferLine.new(Segment:new({ content = "      " }), buttonC)
			local buffer = Buffer.new(line1, line2)

			-- When focused on Button C (line 2, col 6)
			-- Pressing "k" should find closest element above
			-- A is at col 0 (distance 6), B is at col 11 (distance 5)
			-- Should find B (closest to col 6)
			local result = buffer:find_focusable_above({ line = 2, col = 6 })

			eq(true, result.found)
			eq(1, result.pos.line)
			eq(11, result.pos.col)
		end)

		it("finds closest column when exact column not available below", function()
			-- Same irregular layout:
			-- Line 1: [A]          [B]   → A at col 0, B at col 11
			-- Line 2:       [C]          → C at col 6
			local buttonA = Segment:new({ content = "A", is_focusable = true })
			local buttonB = Segment:new({ content = "B", is_focusable = true })
			local buttonC = Segment:new({ content = "C", is_focusable = true })

			local line1 = BufferLine.new(buttonA, Segment:new({ content = "          " }), buttonB)
			local line2 = BufferLine.new(Segment:new({ content = "      " }), buttonC)
			local buffer = Buffer.new(line1, line2)

			-- When focused on Button B (line 1, col 11)
			-- Pressing "j" should find closest element below
			-- C is at col 6 — only option, so should find it
			local result = buffer:find_focusable_below({ line = 1, col = 11 })

			eq(true, result.found)
			eq(2, result.pos.line)
			eq(6, result.pos.col)
		end)
	end)
end)
