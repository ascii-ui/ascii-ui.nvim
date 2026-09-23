-- EXPERIMENTAL: Minimal Neovim init for ascii-ui.nvim debug / live-reload sessions.
--
-- This script is NOT part of the public plugin API and may change or be
-- removed in any future release.
--
-- Launched by scripts/debug via:
--   ASCII_UI_PLUGIN_DIR=... ASCII_UI_DEBUG_FILE=... nvim -u scripts/debug-init.lua
--
-- Reads two environment variables set by the launcher script:
--   ASCII_UI_PLUGIN_DIR  — absolute path to the ascii-ui.nvim repository root
--   ASCII_UI_DEBUG_FILE  — absolute path to the user's debug.lua

-- luacheck: globals vim
local plugin_dir = os.getenv("ASCII_UI_PLUGIN_DIR")
local debug_file = os.getenv("ASCII_UI_DEBUG_FILE")

if not plugin_dir or plugin_dir == "" then
	error("ASCII_UI_PLUGIN_DIR is not set — run this via `make debug` or `scripts/debug`")
end
if not debug_file or debug_file == "" then
	error("ASCII_UI_DEBUG_FILE is not set — run this via `make debug` or `scripts/debug`")
end

-- ─── basic UI ─────────────────────────────────────────────────────────────────
vim.opt.termguicolors = true
vim.opt.laststatus = 0
vim.opt.cmdheight = 1
vim.opt.number = false
vim.opt.signcolumn = "no"
vim.opt.swapfile = false

-- ─── make plugin modules findable ─────────────────────────────────────────────
-- Mirrors what scripts/minimal_init.lua does for the test suite.
local function add_to_luapath(dir)
	package.path = table.concat({
		dir .. "/?.lua",
		dir .. "/?/init.lua",
		package.path,
	}, ";")
end

-- Plugin source
add_to_luapath(plugin_dir .. "/lua")

-- Lux-managed dependencies (e.g. any runtime deps declared in lux.toml)
local lux_deps = vim.fn.glob(plugin_dir .. "/.lux/5.1/**/src", true, true)
for _, dep_dir in ipairs(lux_deps) do
	add_to_luapath(dep_dir)
end

-- ─── start live-reload session ────────────────────────────────────────────────
require("ascii-ui.dev").start(debug_file, plugin_dir)
