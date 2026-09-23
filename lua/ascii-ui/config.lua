--- Default configuration for ascii-ui.
---
--- Visual defaults follow the `editorial` theme: soft rounded borders and
--- comfortable density. `characters`, `symbols` and `density` are derived
--- from the active theme by `user_config.set` unless explicitly overridden;
--- explicit keys always win over theme values.
--- @class ascii-ui.Config
local config = {
	---@type ascii-ui.Logger.LogLevel
	log_level = "INFO",
	---@type string|ascii-ui.ThemeSpec active theme name or inline theme spec
	theme = "editorial",
	---@type ascii-ui.Density layout density (compact/comfortable/spacious)
	density = "comfortable",
	---@type ascii-ui.ThemeSymbols symbol vocabulary (focus/selection/status glyphs)
	symbols = {
		focus = ">",
		selected = "●",
		unselected = "○",
		checked = "✓",
		error = "×",
		warning = "!",
		pending = "▶",
		busy = "↻",
		expand = "▸",
	},
	characters = {
		top_left = "╭",
		top_right = "╮",
		bottom_left = "╰",
		bottom_right = "╯",
		horizontal = "─",
		vertical = "│",
		left_tree = "├",
		thumb = "●",
		whitespace = " ",
		right_triangule = "▸",
		down_triangule = "▾",
	},
	keymaps = {
		quit = "q",
		select = "<CR>",
	},
}

return config
