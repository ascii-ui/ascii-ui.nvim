local Buffer = require("ascii-ui.buffer")
local Bufferline = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local StdoutViewport = require("ascii-ui.viewports.stdout")

local eq = require("tests.assertions").eq

--- Returns a writer spy and a function to retrieve captured output.
local function make_writer()
	local chunks = {}
	local function writer(s)
		table.insert(chunks, s)
	end
	local function output()
		return table.concat(chunks)
	end
	return writer, output
end

--- Strip all ANSI escape sequences from a string.
local function strip_ansi(s)
	return s:gsub("\027%[[%d;]*m", "")
end

describe("StdoutViewport", function()
	describe("update", function()
		it("writes plain buffer lines to output", function()
			local writer, output = make_writer()
			local vp = StdoutViewport.new(writer)

			vp:update(Buffer.from_lines({ "hello", "world" }))

			local plain = strip_ansi(output())
			assert(plain:find("hello", 1, true))
			assert(plain:find("world", 1, true))
		end)

		it("emits ANSI fg truecolor code for a colored segment", function()
			local writer, output = make_writer()
			local vp = StdoutViewport.new(writer)
			local buf = Buffer.new(Bufferline.new(Segment:new({ content = "hi", color = { fg = "#ff0000" } })))

			vp:update(buf)

			-- ESC[38;2;255;0;0m  (fg truecolor for #ff0000)
			assert(output():find("\027%[38;2;255;0;0m", 1))
		end)

		it("emits ANSI bg truecolor code for a colored segment", function()
			local writer, output = make_writer()
			local vp = StdoutViewport.new(writer)
			local buf = Buffer.new(Bufferline.new(Segment:new({ content = "hi", color = { bg = "#0000ff" } })))

			vp:update(buf)

			-- ESC[48;2;0;0;255m  (bg truecolor for #0000ff)
			assert(output():find("\027%[48;2;0;0;255m", 1))
		end)

		it("resets color after each colored segment", function()
			local writer, output = make_writer()
			local vp = StdoutViewport.new(writer)
			local buf = Buffer.new(Bufferline.new(Segment:new({ content = "hi", color = { fg = "#00ff00" } })))

			vp:update(buf)

			local out = output()
			local color_pos = out:find("\027%[38;2;0;255;0m", 1)
			local reset_pos = out:find("\027%[0m", 1)
			assert(color_pos)
			assert(reset_pos)
			assert(reset_pos > color_pos)
		end)

		it("does not emit ANSI codes for plain segments", function()
			local writer, output = make_writer()
			local vp = StdoutViewport.new(writer)

			vp:update(Buffer.from_lines({ "plain text" }))

			eq(strip_ansi(output()), output())
		end)
	end)

	describe("interface", function()
		it("is_focused always returns false", function()
			eq(false, StdoutViewport.new():is_focused())
		end)

		it("get_id returns -1", function()
			eq(-1, StdoutViewport.new():get_id())
		end)

		it("get_bufnr returns -1", function()
			eq(-1, StdoutViewport.new():get_bufnr())
		end)

		it("get_ns_id returns -1", function()
			eq(-1, StdoutViewport.new():get_ns_id())
		end)
	end)
end)
