--- Phase 0 theme system: registry, inheritance, resolution, highlight generation.
---
--- Phase 1 adds the three builtin palettes under `theme/themes/`:
--- `editorial` (default fallback base), `phosphor` (green-phosphor terminal)
--- and `noir` (strict monochrome). All three expose the same 9 foundation +
--- 5 semantic color tokens, so the same dashboard renders under any palette
--- without component rewrites.
---
--- A theme is a named table of color tokens, symbol glyphs, border sets and a
--- density default. The `editorial` theme is always registered; custom themes
--- are added with `define()` and inherit any missing key from `editorial`,
--- so a partial spec like `{ name = "mine", colors = { accent = "#fff" } }`
--- is a complete theme.
---
--- Consuming code never hardcodes hex values: `Color.from_token("accent")`
--- resolves through the active theme, `Segment` accepts token names, and
--- `apply_highlights()` materializes every token as a Neovim highlight group
--- (`AsciiUIAccent`, ...) plus the legacy `SELECTION`/`BUTTON` groups.
---@class ascii-ui.ThemeColors
---@field background string
---@field surface string
---@field elevated string
---@field border string
---@field separator string
---@field text string
---@field text_strong string
---@field text_muted string
---@field text_disabled string
---@field accent string
---@field success string
---@field warning string
---@field error string
---@field info string

---@class ascii-ui.ThemeSymbols
---@field focus string marker for the focused element (`>`)
---@field selected string marker for a selected item (`●`)
---@field unselected string marker for an unselected item (`○`)
---@field checked string checkbox checked glyph (`✓`)
---@field error string failure glyph (`×`)
---@field warning string warning glyph (`!`)
---@field pending string progress/pending glyph (`▶`)
---@field busy string spinner glyph (`↻`)
---@field expand string collapsed-tree glyph (`▸`)

---@class ascii-ui.BorderChars
---@field top_left string
---@field top_right string
---@field bottom_left string
---@field bottom_right string
---@field horizontal string
---@field vertical string
---@field left_tree string
---@field thumb string
---@field whitespace string
---@field right_triangule string
---@field down_triangule string

---@alias ascii-ui.BorderStyle "soft"|"classic"|"heavy"|"editorial"
---@alias ascii-ui.Density "compact"|"comfortable"|"spacious"

---@class ascii-ui.ThemeSpec
---@field name string unique theme name (required for `define`)
---@field colors? table<string, string> partial or full token map (missing keys inherit from editorial)
---@field symbols? ascii-ui.ThemeSymbols
---@field borders? table<ascii-ui.BorderStyle, ascii-ui.BorderChars>
---@field border? ascii-ui.BorderStyle active border style (default `"soft"`)
---@field density? ascii-ui.Density default density (default `"comfortable"`)

---@class ascii-ui.Theme : ascii-ui.ThemeSpec
---@field colors ascii-ui.ThemeColors
---@field symbols ascii-ui.ThemeSymbols
---@field borders table<ascii-ui.BorderStyle, ascii-ui.BorderChars>
---@field border ascii-ui.BorderStyle
---@field density ascii-ui.Density

local theme = {}

---@type table<string, ascii-ui.Theme>
local registry = {}

---@type ascii-ui.Theme|nil
local active = nil

---@type ascii-ui.ThemeSymbols
local DEFAULT_SYMBOLS = {
	focus = ">",
	selected = "●",
	unselected = "○",
	checked = "✓",
	error = "×",
	warning = "!",
	pending = "▶",
	busy = "↻",
	expand = "▸",
}

local SHARED_CHARS = {
	thumb = "●",
	whitespace = " ",
	right_triangule = "▸",
	down_triangule = "▾",
}

---@param border_chars table<string, string>
---@return ascii-ui.BorderChars
local function with_shared(border_chars)
	return vim.tbl_extend("force", SHARED_CHARS, border_chars)
end

---@type table<ascii-ui.BorderStyle, ascii-ui.BorderChars>
local DEFAULT_BORDERS = {
	soft = with_shared({
		top_left = "╭",
		top_right = "╮",
		bottom_left = "╰",
		bottom_right = "╯",
		horizontal = "─",
		vertical = "│",
		left_tree = "├",
	}),
	classic = with_shared({
		top_left = "┌",
		top_right = "┐",
		bottom_left = "└",
		bottom_right = "┘",
		horizontal = "─",
		vertical = "│",
		left_tree = "├",
	}),
	heavy = with_shared({
		top_left = "┏",
		top_right = "┓",
		bottom_left = "┗",
		bottom_right = "┛",
		horizontal = "━",
		vertical = "┃",
		left_tree = "┣",
	}),
	editorial = with_shared({
		top_left = " ",
		top_right = " ",
		bottom_left = " ",
		bottom_right = " ",
		horizontal = "─",
		vertical = " ",
		left_tree = "─",
	}),
}

---@type string[] names of the builtin palettes, in registration order
local BUILTIN_NAMES = { "editorial", "phosphor", "noir" }

--- Compose a complete builtin theme from its palette spec: symbols, border
--- sets, border style and density fall back to the shared defaults, so
--- palette files only carry what makes them distinct (colors + name).
---@param spec ascii-ui.ThemeSpec
---@return ascii-ui.Theme
local function build_builtin(spec)
	local full = vim.tbl_deep_extend("force", {
		symbols = vim.deepcopy(DEFAULT_SYMBOLS),
		borders = vim.deepcopy(DEFAULT_BORDERS),
		border = "soft",
		density = "comfortable",
	}, spec)
	---@cast full ascii-ui.Theme
	return full
end

--- Restore the registry to its builtin state (editorial, phosphor and noir
--- registered; editorial active). Useful for test isolation.
function theme.reset()
	registry = {}
	active = nil
	for _, name in ipairs(BUILTIN_NAMES) do
		local spec = require("ascii-ui.theme.themes." .. name)
		registry[name] = build_builtin(spec)
	end
	active = registry["editorial"]
end

--- Register a theme. themeissing colors, symbols, border sets, border style and
--- density inherit from the `editorial` theme, so partial specs are complete.
--- Registering an existing name replaces that registration.
---@param spec ascii-ui.ThemeSpec
---@return ascii-ui.Theme theme the registered (merged) theme
function theme.define(spec)
	assert(type(spec) == "table", "theme.define expects a table spec")
	assert(type(spec.name) == "string" and #spec.name > 0, "theme.define requires a `name` string")

	local base = registry["editorial"] or build_builtin(require("ascii-ui.theme.themes.editorial"))
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(base), spec)
	merged.name = spec.name
	---@cast merged ascii-ui.Theme
	registry[merged.name] = merged
	return merged
end

--- Derive an ephemeral (unregistered) theme: `overrides` merged over the
--- registered theme `base_name`. Used by `setup({ theme = { ... } })` so
--- inline tables never mutate the shared registry.
---@param base_name string
---@param overrides table<string, any>
---@return ascii-ui.Theme
function theme.derive(base_name, overrides)
	local base = registry[base_name]
	assert(base, ("unknown theme %q (use ui.defineTheme to register it first)"):format(base_name))
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(base), overrides or {})
	---@cast merged ascii-ui.Theme
	return merged
end

---@param name? string theme name; nil returns the active theme
---@return ascii-ui.Theme
function theme.get(name)
	if name == nil then
		assert(active, "no active theme (call theme.reset first)")
		return active
	end
	local found = registry[name]
	assert(found, ("unknown theme %q (use ui.defineTheme to register it first)"):format(name))
	return found
end

--- Set the active theme by registered name and refresh highlight groups.
---@param name string
---@return ascii-ui.Theme theme the now-active theme
function theme.set(name)
	local found = registry[name]
	assert(found, ("unknown theme %q (use ui.defineTheme to register it first)"):format(name))
	active = found
	theme.apply_highlights()
	return active
end

--- Set an already-resolved (ephemeral) theme active and refresh highlights.
---@param new_active ascii-ui.Theme
---@return ascii-ui.Theme
function theme.set_active(new_active)
	assert(type(new_active) == "table" and type(new_active.name) == "string", "theme.set_active expects a theme table")
	active = new_active
	theme.apply_highlights()
	return active
end

---@return string[] names of all registered themes
function theme.list()
	return vim.tbl_keys(registry)
end

--- Resolve a color token to its hex value.
---@param token string e.g. `"accent"`
---@param override? ascii-ui.Theme resolve against this theme instead of the active one
---@return string hex `"#rrggbb"`
function theme.resolve(token, override)
	local source = override or theme.get()
	local hex = source.colors and source.colors[token]
	assert(hex, ("unknown theme token %q"):format(token))
	return hex
end

---@return boolean true when the terminal supports truecolor output
function theme.supports_truecolor()
	return vim.go.termguicolors == true
end

--- Check whether a theme is strictly monochrome: every color token must be
--- grayscale (`#rrggbb` with `r == g == b`). Used as the Noir fallback check —
--- focus, selection and status semantics must survive on symbols and contrast
--- alone, never on hue.
---@param theme_or_name? string|ascii-ui.Theme theme name, theme table, or nil for the active theme
---@return boolean true when all tokens are grayscale
function theme.is_monochrome(theme_or_name)
	local source
	if theme_or_name == nil then
		source = theme.get()
	elseif type(theme_or_name) == "string" then
		source = theme.get(theme_or_name)
	else
		source = theme_or_name
	end
	assert(
		type(source) == "table" and type(source.colors) == "table",
		"theme.is_monochrome expects a theme name or theme table"
	)
	for _, hex in pairs(source.colors) do
		local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
		if r == nil or r:lower() ~= g:lower() or r:lower() ~= b:lower() then
			return false
		end
	end
	return true
end

---@param token string
---@return string capitalized token, e.g. `"accent"` -> `"Accent"`
local function capitalize(token)
	return token:sub(1, 1):upper() .. token:sub(2)
end

--- themeaterialize the active theme as Neovim highlight groups.
---
--- Lifecycle: called automatically by `setup()`, `setTheme()` and
--- `Window.new()`; idempotent (re-applying defines the same groups).
--- Every color token becomes `AsciiUI<Token>` (e.g. `AsciiUIAccent`), and
--- the legacy `SELECTION`/`BUTTON` groups follow the theme accent so
--- existing components pick up theming without rewrites. Stdout parity:
--- the same tokens drive ANSI codes via `Color:to_ansi()`.
function theme.apply_highlights()
	local current = theme.get()
	local highlights = require("ascii-ui.highlights")

	for token, hex in pairs(current.colors) do
		vim.api.nvim_set_hl(0, "AsciiUI" .. capitalize(token), { fg = hex })
	end

	vim.api.nvim_set_hl(0, highlights.SELECTION, { fg = current.colors.accent })
	local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
	vim.api.nvim_set_hl(0, highlights.BUTTON, { fg = normal_bg, bg = current.colors.accent })
end

theme.reset()

return theme
