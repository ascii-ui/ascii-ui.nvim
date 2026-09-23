-- scripts/minimal_init.lua
-- Headless testing with mini.test, no user config loaded.
-- Adapted from https://github.com/rcasia/neotest-java/blob/main/scripts/minimal_init.lua

local DEPENDENCIES_DIR = "./.dependencies"

-- Speed up startup
for _, p in ipairs({
	"gzip",
	"zip",
	"zipPlugin",
	"tar",
	"tarPlugin",
	"vimball",
	"vimballPlugin",
	"2html_plugin",
	"matchit",
	"matchparen",
	"netrw",
	"netrwPlugin",
	"netrwSettings",
	"netrwFileHandlers",
	"rrhelper",
	"spellfile_plugin",
	"shada_plugin",
}) do
	vim.g["loaded_" .. p] = 1
end

vim.opt.shortmess:append("I")
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- ─────────────────────────────────────────────────────────────
-- Ensure dependencies exist (auto-clone if missing)
-- ─────────────────────────────────────────────────────────────
local function ensure_repo(path, url)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
		vim.fn.system({ "git", "clone", "--depth", "1", url, path })
	end
end

ensure_repo(DEPENDENCIES_DIR .. "/mini.nvim", "https://github.com/nvim-mini/mini.nvim")

-- ─────────────────────────────────────────────────────────────
-- Runtime path setup
-- ─────────────────────────────────────────────────────────────
-- ./lua: the plugin itself (require("ascii-ui..."))
-- ./?.lua: test helpers (require("tests.assertions"))
package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/mini.nvim")

-- ─────────────────────────────────────────────────────────────
-- Enable mini.test (busted-style describe/it emulation)
-- ─────────────────────────────────────────────────────────────
require("mini.test").setup({
	collect = {
		emulate_busted = true,
		find_files = function()
			return vim.fn.globpath("tests", "**/*_spec.lua", true, true)
		end,
	},
	execute = {
		reporter = require("mini.test").gen_reporter.stdout(),
		stop_on_error = false,
	},
})

-- ─────────────────────────────────────────────────────────────
-- Fail-fast test entrypoint
-- ─────────────────────────────────────────────────────────────
-- Same as MiniTest.run(opts), except a collection error (e.g. a spec
-- file failing to load) exits headless nvim immediately with code 1.
-- Without this, MiniTest.run() leaves nvim idle forever on collection
-- errors and CI only fails on its step timeout with no useful output.
---@param opts table|nil Same shape as MiniTest.config
function _G.MiniTest_run(opts)
	opts = opts or {}
	local ok, cases = pcall(MiniTest.collect, opts.collect)
	if not ok then
		io.stderr:write("mini.test collection failed:\n" .. tostring(cases) .. "\n")
		vim.cmd("1cquit")
		return
	end
	MiniTest.execute(cases, opts.execute)
end
