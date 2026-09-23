local eq = require("tests.assertions").eq

-- This spec intentionally stubs vim.fn.isdirectory/mkdir and sets
-- vim.env.GITHUB_ACTIONS to exercise the logger's file-system paths.
-- luacheck: ignore 122

--- Tests for ascii-ui.logger
---
--- The logger computes `log_dir`, `log_path` and the RUNNING_ON_ACTIONS flag
--- at require time (and `vim.fn.stdpath` is cached at startup), so tests stub
--- the filesystem functions used by `ensure_log_dir`/`write_log` and reload
--- the module to exercise a specific mode deterministically.

local function reload_logger()
	package.loaded["ascii-ui.logger"] = nil
	return require("ascii-ui.logger")
end

describe("Logger", function()
	local orig_actions
	local orig_isdirectory
	local orig_mkdir
	local orig_io_open
	local mkdir_calls

	before_each(function()
		orig_actions = vim.env.GITHUB_ACTIONS
		orig_isdirectory = vim.fn.isdirectory
		orig_mkdir = vim.fn.mkdir
		orig_io_open = io.open
		mkdir_calls = 0
		-- Pretend the log directory never exists, and never hit the real
		-- log file: io.open returns nil, which write_log already tolerates.
		vim.fn.isdirectory = function()
			return 0
		end
		vim.fn.mkdir = function()
			mkdir_calls = mkdir_calls + 1
			return 1
		end
		io.open = function()
			return nil
		end
	end)

	after_each(function()
		vim.fn.isdirectory = orig_isdirectory
		vim.fn.mkdir = orig_mkdir
		io.open = orig_io_open
		vim.env.GITHUB_ACTIONS = orig_actions
		package.loaded["ascii-ui.logger"] = nil
	end)

	describe("on GitHub Actions", function()
		it("logs to stdout without creating the log directory", function()
			vim.env.GITHUB_ACTIONS = "true"
			local logger = reload_logger()

			logger.debug("hello %s", "world")

			-- On Actions the logger never writes to a file, so it must not
			-- touch the filesystem at all (parallel test workers sharing one
			-- data directory otherwise race on directory creation).
			eq(0, mkdir_calls)
		end)
	end)

	describe("outside GitHub Actions", function()
		it("creates the log directory when missing", function()
			vim.env.GITHUB_ACTIONS = ""
			local logger = reload_logger()
			logger.set_level("DEBUG")

			logger.debug("wrote to file")

			eq(1, mkdir_calls)
		end)

		it("does not raise when mkdir loses the directory creation race", function()
			vim.env.GITHUB_ACTIONS = ""
			-- Simulate the losing side of a concurrent-creation race:
			-- another process created the directory between the
			-- isdirectory() check and mkdir(), so mkdir raises Vim:E739.
			vim.fn.mkdir = function()
				mkdir_calls = mkdir_calls + 1
				error("Vim(mkdir):E739: Cannot create directory: file already exists")
			end
			local logger = reload_logger()
			logger.set_level("DEBUG")

			local ok, err = pcall(logger.debug, "should not crash")

			assert(ok, "logging must never throw: " .. tostring(err))
		end)
	end)
end)
