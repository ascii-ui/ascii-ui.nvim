local Bufferline = require("ascii-ui.buffer.bufferline")
local Color = require("ascii-ui.color")
local Segment = require("ascii-ui.buffer.segment")
local logger = require("ascii-ui.logger")
local mount = require("ascii-ui.mount")
local theme = require("ascii-ui.theme")
local user_config = require("ascii-ui.config.user_config")

--- @class ascii-ui.AsciiUI
local AsciiUI = {
	--- This contains all the components available in the library
	components = require("ascii-ui.components"),
	--- Unified color class for creating colored segments.
	--- See `ascii-ui.Color` for full documentation.
	Color = Color,
	blocks = {
		Bufferline = Bufferline.new,
		---@param opts ascii-ui.SegmentOpts
		Segment = function(opts)
			return Segment:new(opts)
		end,
	},
	createComponent = require("ascii-ui.components.create-component"),
	hooks = require("ascii-ui.hooks"),
	--- Theme system (Phase 0): registry, token resolution, highlight generation.
	---
	--- ```lua
	--- local ui = require("ascii-ui")
	--- ui.defineTheme({ name = "mine", colors = { accent = "#ff0000" } })
	--- ui.setup({ theme = "mine" })
	--- ui.setTheme("editorial") -- runtime switch, hook state preserved
	--- ```
	theme = theme,
	--- Register a theme (partial specs inherit from `editorial`).
	---@param spec ascii-ui.ThemeSpec
	---@return ascii-ui.Theme
	defineTheme = function(spec)
		return theme.define(spec)
	end,
	--- Switch the active theme at runtime. Highlight groups refresh
	--- immediately; all mounted trees re-render with hook state preserved.
	--- Explicit `characters`/`symbols`/`density` overrides from `setup()`
	--- survive the switch.
	---@param name string registered theme name
	---@return ascii-ui.Theme
	setTheme = function(name)
		theme.set(name)
		user_config.sync_from_theme()
		mount.rerender_all()
		return theme.get()
	end,
	--- @param name? string theme name; nil returns the active theme
	---@return ascii-ui.Theme
	getTheme = function(name)
		return theme.get(name)
	end,
	--- This contains the layout class
	layout = require("ascii-ui.layout"),
	mount = mount,
	--- Built-in viewport implementations.
	---
	--- A viewport is any object satisfying the `ascii-ui.Viewport` interface; pass
	--- one as the second argument to `ui.mount` to control where the UI is rendered.
	---
	--- Available viewports:
	---   - `StdoutViewport` — renders to terminal stdout with ANSI truecolor codes.
	---     Useful for headless scripts, animations, or CI pipelines.
	---
	--- Example:
	--- ```lua
	--- local ui = require("ascii-ui")
	--- ui.mount(MyComponent, ui.viewports.StdoutViewport.new())
	--- ```
	testing = require("ascii-ui.testing"),
	viewports = {
		StdoutViewport = require("ascii-ui.viewports.stdout"),
	},

	--- @generic T, U
	--- @param items T[]
	--- @param render_fn fun(item: T, i: integer): U
	--- @return U[]
	map = function(items, render_fn)
		return vim.iter(ipairs(items))
			:map(function(i, item)
				return render_fn(item, i)
			end)
			:totable()
	end,
}

--- EXPERIMENTAL: Load a component from a file and mount it.
---
--- Resolves `file` against cwd (relative paths work naturally when called
--- from `debug.lua` launched by `make debug`).  Executes the file with
--- `dofile()` and mounts the returned component.
---
--- Designed for the live-reload debug session but also works from a
--- running Neovim session:
---   `:lua require("ascii-ui").debug("lua/myplugin/MyComp.lua")`
---
--- When a `watcher` is not provided, a `BufWritePost` autocmd is registered
--- for the loaded file. Each save closes the current window and re-mounts
--- the component automatically (live-reload).
---
--- @param file string Path to a Lua file that returns a component.
--- @param opts? { loader?: fun(path: string): any, mounter?: fun(comp: any): integer, notifier?: fun(msg: string, level: integer), watcher?: fun(path: string, bufnr: integer, reload: fun()) }
--- @return integer|nil bufnr
function AsciiUI.debug(file, opts)
	opts = opts or {}
	local loader = opts.loader or dofile
	local mounter = opts.mounter or mount
	local notifier = opts.notifier or vim.notify

	local abs_path = vim.fn.fnamemodify(file, ":p")
	local ok, result = pcall(loader, abs_path)
	if not ok then
		notifier("[ascii-ui] debug: error loading " .. file .. ":\n" .. tostring(result), vim.log.levels.ERROR)
		return nil
	end

	local bufnr = mounter(result)

	-- Determine the watcher to use.
	-- • opts.watcher provided → caller controls watching (useful for tests and custom setups)
	-- • opts.watcher absent   → register a default BufWritePost autocmd so that saving the
	--   component file closes the old window and re-mounts automatically (live-reload).
	local watcher = opts.watcher
	if watcher == nil then
		watcher = function(path, buf, reload)
			local winid = vim.fn.bufwinid(buf or -1)
			local autocmd_id
			autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
				pattern = path,
				callback = function()
					-- Remove ourselves; the re-mount will register a fresh watcher.
					vim.api.nvim_del_autocmd(autocmd_id)
					if vim.api.nvim_win_is_valid(winid) then
						vim.api.nvim_win_close(winid, true)
					end
					vim.schedule(reload)
				end,
			})
		end
	end

	if type(watcher) == "function" then
		watcher(abs_path, bufnr, function()
			AsciiUI.debug(file, opts)
		end)
	end

	return bufnr
end

function AsciiUI.setup(config)
	config = config or {}
	user_config.set(config)

	logger.set_level(user_config.get().log_level)
	return AsciiUI
end

setmetatable(AsciiUI, {
	__call = function(self, config)
		return self.setup(config)
	end,
})

return AsciiUI
