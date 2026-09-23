local logger = require("ascii-ui.logger")
local theme = require("ascii-ui.theme")

local DEFAULT_CONFIG = require("ascii-ui.config")

--- @type ascii-ui.Config
local _config = DEFAULT_CONFIG

--- Explicit per-key overrides from the last `set()` call. These survive
--- `sync_from_theme()` (triggered by `setTheme`), so a user's partial
--- `characters`/`symbols`/`density` config is not wiped by theme switches.
local last_explicit = { characters = {}, symbols = {}, density = nil }

--- Re-derive theme-driven config keys from the active theme, preserving
--- explicit overrides recorded by `set()`. Also refreshes highlight groups.
local function sync_from_theme()
	local current = theme.get()
	_config.characters = vim.tbl_extend("force", current.borders[current.border], last_explicit.characters)
	_config.symbols = vim.tbl_extend("force", current.symbols, last_explicit.symbols)
	if last_explicit.density == nil then
		_config.density = current.density
	end
	_config.theme = current.name
	theme.apply_highlights()
end

return {
	set = function(new_config)
		logger.debug("Setting user config %s", vim.inspect(new_config))
		if type(new_config) ~= "table" then
			error("UserConfig must be a table")
		end
		-- merge default config with user config
		_config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, new_config)

		-- record explicit overrides so theme switches preserve them
		last_explicit = { characters = {}, symbols = {}, density = nil }
		if new_config.characters ~= nil then
			last_explicit.characters = vim.deepcopy(new_config.characters)
		end
		if new_config.symbols ~= nil then
			last_explicit.symbols = vim.deepcopy(new_config.symbols)
		end
		if new_config.density ~= nil then
			last_explicit.density = new_config.density
		end

		-- select the requested theme: a name activates a registered theme,
		-- a table derives an ephemeral theme (registry untouched)
		if type(new_config.theme) == "string" then
			theme.set(new_config.theme)
		elseif type(new_config.theme) == "table" then
			local inline = new_config.theme
			local base_name = inline.name or theme.get().name
			theme.set_active(theme.derive(base_name, inline))
		end

		sync_from_theme()
	end,
	get = function()
		return _config
	end,
	sync_from_theme = sync_from_theme,
}
