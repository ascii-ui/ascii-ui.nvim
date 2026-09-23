local eq = require("tests.assertions").eq

local ui = require("ascii-ui")

describe("ui.debug", function()
	it("calls mounter with the component returned by loader", function()
		local component = ui.createComponent("Fixture", function()
			return {}
		end)

		local captured = nil
		ui.debug("any/path.lua", {
			loader = function(_)
				return component
			end,
			mounter = function(comp)
				captured = comp
			end,
		})

		eq(component, captured)
	end)

	it("returns the value from mounter", function()
		local bufnr = ui.debug("any/path.lua", {
			loader = function(_)
				return ui.createComponent("Fixture", function()
					return {}
				end)
			end,
			mounter = function(_)
				return 99
			end,
		})

		eq(99, bufnr)
	end)

	describe("when loader throws", function()
		local function broken_loader(_)
			error("syntax error in component file")
		end

		it("calls notifier with ERROR level", function()
			local notified = nil
			ui.debug("bad/path.lua", {
				loader = broken_loader,
				mounter = function(_) end,
				notifier = function(msg, level)
					notified = { msg = msg, level = level }
				end,
			})

			assert(notified ~= nil)
			eq(vim.log.levels.ERROR, notified.level)
		end)

		it("does not call mounter", function()
			local mounter_called = false
			ui.debug("bad/path.lua", {
				loader = broken_loader,
				mounter = function(_)
					mounter_called = true
				end,
				notifier = function(_) end,
			})

			assert(not mounter_called)
		end)

		it("returns nil", function()
			local result = ui.debug("bad/path.lua", {
				loader = broken_loader,
				mounter = function(_) end,
				notifier = function(_) end,
			})

			assert(result == nil)
		end)
	end)

	describe("integration", function()
		it("loads a real component file with dofile and mounts it", function()
			local fixture = vim.fn.fnamemodify("tests/util/debug_fixture_comp.lua", ":p")
			local bufnr = ui.debug(fixture)

			assert(type(bufnr) == "number")
			assert(bufnr > 0)

			-- wait for the component to render into the buffer
			local found = vim.wait(1000, function()
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				local content = table.concat(lines, "\n")
				return content:find("debug fixture loaded", 1, true) ~= nil
			end)
			assert(found)
		end)
	end)

	describe("live-reload watcher", function()
		local function make_component()
			return ui.createComponent("Fixture", function()
				return {}
			end)
		end

		it("calls watcher with (abs_path, bufnr, reload) after a successful mount", function()
			local abs = vim.fn.fnamemodify("any/comp.lua", ":p")
			local captured = nil

			ui.debug("any/comp.lua", {
				loader = function(_)
					return make_component()
				end,
				mounter = function(_)
					return 77
				end,
				watcher = function(path, bufnr, reload)
					captured = { path = path, bufnr = bufnr, reload = reload }
				end,
			})

			assert(captured ~= nil, "expected watcher to be called")
			eq(abs, captured.path)
			eq(77, captured.bufnr)
			assert(type(captured.reload) == "function")
		end)

		it("calling reload re-runs loader and mounter", function()
			local load_count = 0
			local mount_count = 0
			local captured_reload = nil

			ui.debug("any/comp.lua", {
				loader = function(_)
					load_count = load_count + 1
					return make_component()
				end,
				mounter = function(_)
					mount_count = mount_count + 1
					return mount_count
				end,
				watcher = function(_, _, reload)
					captured_reload = reload
				end,
			})

			assert(captured_reload ~= nil, "expected watcher to be called with reload fn")
			eq(1, load_count)
			eq(1, mount_count)

			captured_reload()

			eq(2, load_count)
			eq(2, mount_count)
		end)

		it("does not call watcher when loader throws", function()
			local watcher_called = false

			ui.debug("bad/path.lua", {
				loader = function(_)
					error("broken")
				end,
				mounter = function(_) end,
				notifier = function(_) end,
				watcher = function(_, _, _)
					watcher_called = true
				end,
			})

			assert(not watcher_called)
		end)
	end)
end)
