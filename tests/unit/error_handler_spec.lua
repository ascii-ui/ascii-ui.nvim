local eq = require("tests.assertions").eq

local error_handler = require("ascii-ui.utils.error_handler")

describe("error_handler", function()
	describe("format_error", function()
		it("formats a render error with component path", function()
			local err = error_handler.format_error("render", "Root > App > MenuItem", "expected list, got string")
			eq("[render] in <Root > App > MenuItem>: expected list, got string", err)
		end)

		it("formats a hook error", function()
			local err = error_handler.format_error("hook", "App > Sidebar", "useState called outside render")
			eq("[hook] in <App > Sidebar>: useState called outside render", err)
		end)

		it("formats an effect error", function()
			local err = error_handler.format_error("effect", "Button", "effect exploded")
			eq("[effect] in <Button>: effect exploded", err)
		end)

		it("formats an interaction error", function()
			local err = error_handler.format_error("interaction", "Select", "on_select failed")
			eq("[interaction] in <Select>: on_select failed", err)
		end)

		it("formats a viewport error", function()
			local err = error_handler.format_error("viewport", "Root", "window creation failed")
			eq("[viewport] in <Root>: window creation failed", err)
		end)

		it("handles nil component path gracefully", function()
			local err = error_handler.format_error("render", nil, "something broke")
			eq("[render] in <unknown>: something broke", err)
		end)

		it("handles empty component path", function()
			local err = error_handler.format_error("render", "", "something broke")
			eq("[render] in <unknown>: something broke", err)
		end)
	end)

	describe("render_error_to_lines", function()
		it("returns a table of strings", function()
			local err = {
				err_type = "render",
				component_path = "Root > App",
				message = "expected list, got string",
			}
			local lines = error_handler.render_error_to_lines(err)
			eq("table", type(lines))
			assert(#lines > 0)
		end)

		it("includes error header", function()
			local err = {
				err_type = "render",
				component_path = "Root > App",
				message = "test error",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("RENDER ERROR"))
		end)

		it("includes error type", function()
			local err = {
				err_type = "hook",
				component_path = "App",
				message = "hook failed",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("Type: hook"))
		end)

		it("includes component path", function()
			local err = {
				err_type = "render",
				component_path = "Root > App > MenuItem",
				message = "test error",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("Component: Root > App > MenuItem"))
		end)

		it("includes error message", function()
			local err = {
				err_type = "render",
				component_path = "App",
				message = "something went wrong",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("Message: something went wrong"))
		end)

		it("includes hint for render errors", function()
			local err = {
				err_type = "render",
				component_path = "App",
				message = "expected list, got string",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("Hint:"))
		end)

		it("includes hint for hook errors", function()
			local err = {
				err_type = "hook",
				component_path = "App",
				message = "useState called outside render",
			}
			local lines = error_handler.render_error_to_lines(err)
			local joined = table.concat(lines, "\n")
			assert(joined:find("Hint:"))
		end)

		it("includes closing border", function()
			local err = {
				err_type = "render",
				component_path = "App",
				message = "test",
			}
			local lines = error_handler.render_error_to_lines(err)
			local last_line = lines[#lines]
			assert(last_line:find("═"))
		end)

		it("returns lines with no embedded newlines", function()
			local err = {
				err_type = "render",
				component_path = "Root > App",
				message = "expected list, got string",
			}
			local lines = error_handler.render_error_to_lines(err)
			for i, line in ipairs(lines) do
				assert(line:find("\n", 1, true) == nil, string.format("line %d contains newline: %q", i, line))
			end
		end)

		it("splits multi-line error messages into separate lines", function()
			local err = {
				err_type = "render",
				component_path = "App",
				message = "line1\nline2\nline3",
			}
			local lines = error_handler.render_error_to_lines(err)
			local found_line1 = false
			local found_line2 = false
			local found_line3 = false
			for _, line in ipairs(lines) do
				if line:find("line1") then
					found_line1 = true
				end
				if line:find("line2") then
					found_line2 = true
				end
				if line:find("line3") then
					found_line3 = true
				end
			end
			assert(found_line1, "should contain line1")
			assert(found_line2, "should contain line2")
			assert(found_line3, "should contain line3")
		end)

		it("handles all error types without embedded newlines", function()
			local err_types = { "render", "hook", "effect", "interaction", "viewport" }
			for _, err_type in ipairs(err_types) do
				local err = {
					err_type = err_type,
					component_path = "App",
					message = "test error",
				}
				local lines = error_handler.render_error_to_lines(err)
				for i, line in ipairs(lines) do
					assert(
						line:find("\n", 1, true) == nil,
						string.format("err_type=%s line %d contains newline: %q", err_type, i, line)
					)
				end
			end
		end)
	end)

	describe("create_error", function()
		it("creates an error table with all fields", function()
			local err = error_handler.create_error("render", "Root > App", "test message")
			eq("render", err.err_type)
			eq("Root > App", err.component_path)
			eq("test message", err.message)
		end)

		it("handles nil component path", function()
			local err = error_handler.create_error("render", nil, "test")
			eq("unknown", err.component_path)
		end)
	end)

	describe("get_hint", function()
		it("returns hint for render errors", function()
			local hint = error_handler.get_hint("render")
			assert(hint)
			eq("string", type(hint))
			assert(#hint > 0)
		end)

		it("returns hint for hook errors", function()
			local hint = error_handler.get_hint("hook")
			assert(hint)
			assert(#hint > 0)
		end)

		it("returns hint for effect errors", function()
			local hint = error_handler.get_hint("effect")
			assert(hint)
			assert(#hint > 0)
		end)

		it("returns hint for interaction errors", function()
			local hint = error_handler.get_hint("interaction")
			assert(hint)
			assert(#hint > 0)
		end)

		it("returns hint for viewport errors", function()
			local hint = error_handler.get_hint("viewport")
			assert(hint)
			assert(#hint > 0)
		end)

		it("returns generic hint for unknown error types", function()
			local hint = error_handler.get_hint("unknown_type")
			assert(hint)
			assert(#hint > 0)
		end)
	end)
end)
