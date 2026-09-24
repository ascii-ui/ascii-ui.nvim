-- EXPERIMENTAL: ascii-ui.nvim live-reload / debug module.
--
-- This module is NOT part of the public plugin API and may change or be
-- removed in any future release.  It is intended solely for contributors
-- and plugin authors who want a fast inner-loop while working on ascii-ui
-- itself or on a plugin built on top of it.
--
-- Launched by scripts/debug-init.lua.
--
-- Responsibilities:
--   1. Run the user's debug.lua on startup.
--   2. Watch the plugin directory (recursively) for .lua changes.
--   3. On any change: close open floating windows, unload all ascii-ui
--      modules from package.loaded, then re-run debug.lua.

local async = require("ascii-ui.utils.async")

local M = {}

-- Module-level state.  All closures (autocmd, fs_event callbacks) capture these
-- upvalue cells directly, so they remain valid even if package.loaded is cleared.
local _debug_file = nil
local _plugin_dir = nil
local _reload_timer = nil
local _watchers = {}
-- Timestamp of the last reload start (vim.uv.now() ms).  Used to absorb the
-- spurious second event that editors and FSEvents/kqueue often emit for a
-- single save (e.g. BufWritePost fires, then the fs_event fires 50 ms later).
local _last_reload = 0
local COOLDOWN_MS = 500

-- ─── helpers ──────────────────────────────────────────────────────────────────

--- Remove every ascii-ui.* entry from package.loaded so the next require()
--- re-executes the source files from disk.
--- ascii-ui.dev itself is kept loaded so the watchers and upvalue state
--- remain stable across reloads.
local function unload_modules()
	for key in pairs(package.loaded) do
		if key:match("^ascii%-ui") and key ~= "ascii-ui.dev" then
			package.loaded[key] = nil
		end
	end
end

--- Close every floating window that is currently open (best-effort).
--- The WinClosed autocmd registered by mount.lua fires synchronously and runs
--- per-mount cleanup (bus:trigger("ui_close"), fiberRoot:unmount(), etc.).
local function close_float_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
		if ok and cfg.relative and cfg.relative ~= "" then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
end

--- Execute the user's debug.lua, surfacing errors as vim notifications.
local function run_debug_file()
	local ok, err = pcall(dofile, _debug_file)
	if not ok then
		vim.notify("[ascii-ui dev] Error in debug.lua:\n" .. tostring(err), vim.log.levels.ERROR)
	end
end

-- ─── reload cycle ─────────────────────────────────────────────────────────────

local function do_reload()
	-- Cooldown guard: absorb duplicate events fired within COOLDOWN_MS of the
	-- last reload (e.g. BufWritePost + a late-arriving FSEvents notification for
	-- the same save, or an editor that emits two events per atomic write).
	if vim.uv.now() - _last_reload < COOLDOWN_MS then
		return
	end
	_last_reload = vim.uv.now()

	vim.notify("[ascii-ui dev] reloading...", vim.log.levels.INFO)

	-- 1. Close any mounted windows so WinClosed cleanup runs synchronously.
	close_float_windows()

	-- 2. Yield one tick so WinClosed autocmds can finish, then swap modules.
	vim.schedule(function()
		unload_modules()
		run_debug_file()
	end)
end

--- Debounce rapid file-change events into a single reload.
--- Uses the async compat layer so the pending reload is a cancellable
--- `vim.async` task on new Neovims and a `vim.uv` timer otherwise.
local function schedule_reload()
	if _reload_timer then
		_reload_timer:close()
		_reload_timer = nil
	end
	_reload_timer = async.after(150, function()
		_reload_timer = nil
		do_reload()
	end)
end

-- ─── file watching ────────────────────────────────────────────────────────────

--- Start a uv fs_event watcher on `path`.
---
--- IMPORTANT: the handle is inserted into `_watchers` BEFORE calling :start()
--- so it is never garbage-collected regardless of what :start() returns.
--- (Some Neovim/luv versions return nil on success instead of true/0, which
--- would make a conditional insert miss the handle and let GC kill the watcher.)
---
--- We watch the whole plugin directory recursively rather than individual files.
--- A recursive directory watch (FSEvents on macOS, ReadDirectoryChangesW on
--- Windows) is resilient to atomic saves where the editor writes a temp file
--- then renames it — a rename changes the inode, which breaks a single-file
--- kqueue watcher and causes it to go silent after the first event.
---@param path string
---@param recursive boolean
local function watch(path, recursive)
	local handle = vim.uv.new_fs_event()
	-- Keep the handle alive unconditionally.
	table.insert(_watchers, handle)

	handle:start(path, { recursive = recursive }, function(ferr, filename, _events)
		if ferr then
			return
		end
		-- For recursive directory watches, only react to .lua file changes.
		if recursive and not (filename and filename:match("%.lua$")) then
			return
		end
		vim.schedule(schedule_reload)
	end)
end

--- BufWritePost autocmd: reliable fallback for in-nvim saves and for Linux
--- where recursive uv.fs_event is not supported by inotify.
local function watch_via_autocmd()
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.lua",
		callback = function(ev)
			local file = vim.fn.fnamemodify(ev.file, ":p")
			if file:find(_plugin_dir, 1, true) == 1 then
				schedule_reload()
			end
		end,
	})
end

-- ─── public API ───────────────────────────────────────────────────────────────

--- Start the live-reload debug session.
---@param debug_file string  Absolute path to the user's debug.lua.
---@param plugin_dir  string  Absolute path to the ascii-ui.nvim root.
function M.start(debug_file, plugin_dir)
	_debug_file = debug_file
	_plugin_dir = plugin_dir

	-- Initial run.
	run_debug_file()

	-- Watch the whole plugin root recursively.  This covers both lua/ascii-ui/**
	-- and debug.lua sitting in the root, with no single-file inode fragility.
	watch(plugin_dir, true)

	-- BufWritePost autocmd: always-correct fallback (works on Linux, works when
	-- the fs_event latency causes it to fire after the debounce window).
	watch_via_autocmd()

	vim.notify("[ascii-ui dev] watching for changes — edit any .lua file to reload", vim.log.levels.INFO)
end

return M
