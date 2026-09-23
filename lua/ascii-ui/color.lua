--- A unified color representation for ascii-ui segments.
---
--- `Color` encapsulates foreground and background colors and provides methods
--- to convert them to Neovim highlight groups (with caching) or ANSI truecolor
--- escape sequences for terminal output.
---
--- ```lua
--- local ui = require("ascii-ui")
---
--- -- Table form (both fg and bg optional)
--- local red_on_white = ui.Color.new({ fg = "#ff0000", bg = "#ffffff" })
---
--- -- String shorthand (treated as foreground only)
--- local red = ui.Color.new("#ff0000")
---
--- -- Use with segments
--- local segment = ui.blocks.Segment({ content = "hello", color = red })
--- -- or with string shorthand:
--- local segment2 = ui.blocks.Segment({ content = "hello", color = "#ff0000" })
--- ```
---@class ascii-ui.Color
---@field fg? string foreground color in "#rrggbb" format
---@field bg? string background color in "#rrggbb" format
local Color = {}
Color.__index = Color

--- Module-level cache for highlight groups, keyed by "fg_bg" string.
---@type table<string, string>
local hl_group_cache = {}

--- Module-level cache for Color instances, keyed by "fg_bg" string.
---@type table<string, ascii-ui.Color>
local color_cache = {}

--- Normalize a hex color string to lowercase "#rrggbb" format.
--- Accepts "#rgb", "#rrggbb", "rgb", "rrggbb".
---@param hex string
---@return string normalized "#rrggbb" or nil if invalid
local function normalize_hex(hex)
	if type(hex) ~= "string" then
		return nil
	end
	-- Strip leading #
	local clean = hex:gsub("^#", "")
	-- Expand 3-char hex to 6-char
	if #clean == 3 then
		clean = clean:sub(1, 1):rep(2) .. clean:sub(2, 2):rep(2) .. clean:sub(3, 3):rep(2)
	end
	-- Validate 6-char hex
	if #clean ~= 6 or not clean:match("^[0-9a-fA-F]+$") then
		return nil
	end
	return "#" .. clean:lower()
end

--- Create a cache key from fg and bg.
---@param fg? string
---@param bg? string
---@return string
local function make_key(fg, bg)
	return (fg or "NONE") .. "_" .. (bg or "NONE")
end

--- Convert HSL values to RGB.
--- H: 0-360 (hue), S: 0-100 (saturation), L: 0-100 (lightness)
--- Returns R, G, B in range 0-255.
---@param h number hue (0-360)
---@param s number saturation (0-100)
---@param l number lightness (0-100)
---@return number r red (0-255)
---@return number g green (0-255)
---@return number b blue (0-255)
local function hsl_to_rgb(h, s, l)
	-- Normalize values to 0-1 range
	h = h / 360
	s = s / 100
	l = l / 100

	local r, g, b

	if s == 0 then
		-- Achromatic (gray)
		r, g, b = l, l, l
	else
		local function hue_to_rgb(p, q, t)
			if t < 0 then
				t = t + 1
			end
			if t > 1 then
				t = t - 1
			end
			if t < 1 / 6 then
				return p + (q - p) * 6 * t
			end
			if t < 1 / 2 then
				return q
			end
			if t < 2 / 3 then
				return p + (q - p) * (2 / 3 - t) * 6
			end
			return p
		end

		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		r = hue_to_rgb(p, q, h + 1 / 3)
		g = hue_to_rgb(p, q, h)
		b = hue_to_rgb(p, q, h - 1 / 3)
	end

	-- Convert to 0-255 range and round
	return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

--- Convert RGB values to HSL.
--- R, G, B: 0-255
--- Returns H: 0-360, S: 0-100, L: 0-100.
---@param r number red (0-255)
---@param g number green (0-255)
---@param b number blue (0-255)
---@return number h hue (0-360)
---@return number s saturation (0-100)
---@return number l lightness (0-100)
local function rgb_to_hsl(r, g, b)
	-- Normalize to 0-1
	r = r / 255
	g = g / 255
	b = b / 255

	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h, s, l
	l = (max + min) / 2

	if max == min then
		-- Achromatic
		h, s = 0, 0
	else
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)

		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	-- Convert to output ranges
	return math.floor(h * 360 + 0.5), math.floor(s * 100 + 0.5), math.floor(l * 100 + 0.5)
end

--- Clamp a value between min and max.
---@param value number
---@param min_val number
---@param max_val number
---@return number
local function clamp(value, min_val, max_val)
	return math.max(min_val, math.min(max_val, value))
end

--- Convert hex color string to RGB values.
---@param hex string "#rrggbb" format
---@return number r red (0-255)
---@return number g green (0-255)
---@return number b blue (0-255)
local function hex_to_rgb(hex)
	local r = tonumber(hex:sub(2, 3), 16)
	local g = tonumber(hex:sub(4, 5), 16)
	local b = tonumber(hex:sub(6, 7), 16)
	return r, g, b
end

--- Convert RGB values to hex color string.
---@param r number red (0-255)
---@param g number green (0-255)
---@param b number blue (0-255)
---@return string hex "#rrggbb" format
local function rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

--- Creates a new Color instance.
---
--- Accepts either:
---   - A table `{ fg = "#rrggbb", bg = "#rrggbb" }` (both fields optional)
---   - A string `"#rrggbb"` (treated as `{ fg = "#rrggbb" }`)
---
--- Identical colors are cached and return the same instance.
---@param opts string | { fg?: string, bg?: string }
---@return ascii-ui.Color
function Color.new(opts)
	local fg, bg

	if type(opts) == "string" then
		fg = normalize_hex(opts)
		bg = nil
	elseif type(opts) == "table" then
		-- If it's already a Color instance, return it
		if getmetatable(opts) == Color then
			return opts
		end
		fg = normalize_hex(opts.fg)
		bg = normalize_hex(opts.bg)
	else
		error("Color.new expects a string or table, got " .. type(opts))
	end

	local key = make_key(fg, bg)

	if color_cache[key] then
		return color_cache[key]
	end

	local state = { fg = fg, bg = bg }
	setmetatable(state, Color)
	color_cache[key] = state
	return state
end

--- Returns a Neovim highlight group name for this color.
--- Creates the group on first call and caches it for subsequent calls.
---@return string highlight_group_name
function Color:to_hl_group()
	local key = make_key(self.fg, self.bg)

	if hl_group_cache[key] then
		return hl_group_cache[key]
	end

	local group_name = ("AsciiUI_fg%s_bg%s"):format(self.fg or "NONE", self.bg or "NONE"):gsub("#", "")

	vim.api.nvim_set_hl(0, group_name, { fg = self.fg, bg = self.bg })
	hl_group_cache[key] = group_name
	return group_name
end

--- Returns ANSI truecolor escape sequences for this color.
--- Produces foreground (`ESC[38;2;r;g;bm`) and/or background (`ESC[48;2;r;g;bm`)
--- codes as appropriate. Returns empty string if neither fg nor bg is set.
---@return string ansi_escape
function Color:to_ansi()
	local ESC = "\027"
	local ANSI_SGR_FMT = ESC .. "[%d;2;%d;%d;%dm"
	local SGR_FG = 38
	local SGR_BG = 48

	local parts = {}

	if self.fg then
		local r = tonumber(self.fg:sub(2, 3), 16)
		local g = tonumber(self.fg:sub(4, 5), 16)
		local b = tonumber(self.fg:sub(6, 7), 16)
		table.insert(parts, ANSI_SGR_FMT:format(SGR_FG, r, g, b))
	end

	if self.bg then
		local r = tonumber(self.bg:sub(2, 3), 16)
		local g = tonumber(self.bg:sub(4, 5), 16)
		local b = tonumber(self.bg:sub(6, 7), 16)
		table.insert(parts, ANSI_SGR_FMT:format(SGR_BG, r, g, b))
	end

	return table.concat(parts)
end

--- Returns true if neither fg nor bg is set.
---@return boolean
function Color:is_empty()
	return self.fg == nil and self.bg == nil
end

--- Check if an object is a Color instance.
---@param obj any
---@return boolean
function Color.is_color(obj)
	return type(obj) == "table" and obj.__index == Color.__index
end

--- Creates a Color from HSL values.
--- H: 0-360 (hue), S: 0-100 (saturation), L: 0-100 (lightness).
--- Values are clamped to valid ranges.
---@param h number hue (0-360)
---@param s number saturation (0-100)
---@param l number lightness (0-100)
---@return ascii-ui.Color
function Color.from_hsl(h, s, l)
	-- Clamp values to valid ranges
	h = clamp(h, 0, 360)
	s = clamp(s, 0, 100)
	l = clamp(l, 0, 100)

	local r, g, b = hsl_to_rgb(h, s, l)
	local hex = rgb_to_hex(r, g, b)
	return Color.new(hex)
end

--- Returns the HSL representation of this color's foreground.
--- Returns nil if fg is not set.
---@return number? h hue (0-360)
---@return number? s saturation (0-100)
---@return number? l lightness (0-100)
function Color:to_hsl()
	if not self.fg then
		return nil, nil, nil
	end
	local r, g, b = hex_to_rgb(self.fg)
	return rgb_to_hsl(r, g, b)
end

--- Returns a new Color with lightness increased by the given amount.
--- Amount is 0-100. Result is clamped.
---@param amount number lightness increase (0-100)
---@return ascii-ui.Color
function Color:lighten(amount)
	if not self.fg then
		return self
	end
	local h, s, l = self:to_hsl()
	l = clamp(l + amount, 0, 100)
	return Color.from_hsl(h, s, l)
end

--- Returns a new Color with lightness decreased by the given amount.
--- Amount is 0-100. Result is clamped.
---@param amount number lightness decrease (0-100)
---@return ascii-ui.Color
function Color:darken(amount)
	if not self.fg then
		return self
	end
	local h, s, l = self:to_hsl()
	l = clamp(l - amount, 0, 100)
	return Color.from_hsl(h, s, l)
end

--- Returns the complement color (hue rotated 180 degrees).
---@return ascii-ui.Color
function Color:complement()
	if not self.fg then
		return self
	end
	local h, s, l = self:to_hsl()
	h = (h + 180) % 360
	return Color.from_hsl(h, s, l)
end

--- Returns a new Color with saturation increased by the given amount.
--- Amount is 0-100. Result is clamped.
---@param amount number saturation increase (0-100)
---@return ascii-ui.Color
function Color:saturate(amount)
	if not self.fg then
		return self
	end
	local h, s, l = self:to_hsl()
	s = clamp(s + amount, 0, 100)
	return Color.from_hsl(h, s, l)
end

--- Returns a new Color with saturation decreased by the given amount.
--- Amount is 0-100. Result is clamped.
---@param amount number saturation decrease (0-100)
---@return ascii-ui.Color
function Color:desaturate(amount)
	if not self.fg then
		return self
	end
	local h, s, l = self:to_hsl()
	s = clamp(s - amount, 0, 100)
	return Color.from_hsl(h, s, l)
end

--- Resolves a theme token (e.g. `"accent"`) to a Color through the active
--- theme (or `override` when given). Unknown tokens raise an error so typos
--- fail fast instead of rendering uncolored.
---@param token string theme token name
---@param override? ascii-ui.Theme resolve against this theme instead of the active one
---@return ascii-ui.Color
function Color.from_token(token, override)
	local theme = require("ascii-ui.theme")
	return Color.new({ fg = theme.resolve(token, override) })
end

--- The 16 standard terminal colors used for the no-truecolor fallback,
--- ordered so the index maps to SGR codes 30-37 (normal) / 90-97 (bright).
---@type string[]
local ANSI16_PALETTE = {
	"#000000",
	"#aa0000",
	"#00aa00",
	"#aa5500",
	"#0000aa",
	"#aa00aa",
	"#00aaaa",
	"#aaaaaa",
	"#555555",
	"#ff5555",
	"#55ff55",
	"#ffff55",
	"#5555ff",
	"#ff55ff",
	"#55ffff",
	"#ffffff",
}

---@param hex string "#rrggbb"
---@return integer index 1-based index into ANSI16_PALETTE of the nearest color
local function nearest_ansi16(hex)
	local r, g, b = hex_to_rgb(hex)
	local best, best_dist = 1, nil
	for i, candidate in ipairs(ANSI16_PALETTE) do
		local cr, cg, cb = hex_to_rgb(candidate)
		local dist = (r - cr) ^ 2 + (g - cg) ^ 2 + (b - cb) ^ 2
		if best_dist == nil or dist < best_dist then
			best, best_dist = i, dist
		end
	end
	return best
end

--- Returns ANSI escape sequences using the 16 standard terminal colors.
--- This is the no-truecolor fallback used when `theme.supports_truecolor()`
--- is false: the nearest standard color is picked per channel. Prefer
--- `to_ansi()` (truecolor) when the terminal supports it.
---@return string ansi_escape
function Color:to_ansi16()
	local parts = {}

	if self.fg then
		local idx = nearest_ansi16(self.fg) - 1
		if idx < 8 then
			table.insert(parts, ("\027[%dm"):format(30 + idx))
		else
			table.insert(parts, ("\027[%dm"):format(90 + idx - 8))
		end
	end

	if self.bg then
		local idx = nearest_ansi16(self.bg) - 1
		if idx < 8 then
			table.insert(parts, ("\027[%dm"):format(40 + idx))
		else
			table.insert(parts, ("\027[%dm"):format(100 + idx - 8))
		end
	end

	return table.concat(parts)
end

return Color
