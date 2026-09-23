local Color = require("ascii-ui.color")
local Segment = require("ascii-ui.buffer.segment")
local theme = require("ascii-ui.theme")
local ui = require("ascii-ui")
local user_config = require("ascii-ui.config.user_config")

local eq = require("tests.assertions").eq

local FOUNDATION_TOKENS = {
	"background",
	"surface",
	"elevated",
	"border",
	"separator",
	"text",
	"text_strong",
	"text_muted",
	"text_disabled",
}

local SEMANTIC_TOKENS = { "accent", "success", "warning", "error", "info" }

---@param s string
---@return boolean
local function is_hex(s)
	return type(s) == "string" and s:match("^#%x%x%x%x%x%x$") ~= nil
end

---@param hex string "#rrggbb"
---@return integer
local function hex_to_number(hex)
	return tonumber(hex:sub(2), 16)
end

describe("theme palettes (Phase 1 tokens and palettes)", function()
	before_each(function()
		theme.reset()
		user_config.set({})
	end)

	describe("builtin palettes", function()
		it("registers editorial, phosphor and noir by default", function()
			assert(vim.tbl_contains(theme.list(), "editorial"))
			assert(vim.tbl_contains(theme.list(), "phosphor"))
			assert(vim.tbl_contains(theme.list(), "noir"))
		end)

		it("defaults to the editorial palette", function()
			eq("editorial", theme.get().name)
		end)

		it("exposes all foundation and semantic tokens as hex on every palette", function()
			for _, name in ipairs({ "editorial", "phosphor", "noir" }) do
				local t = theme.get(name)
				for _, token in ipairs(FOUNDATION_TOKENS) do
					assert(is_hex(t.colors[token]), name .. " missing foundation token: " .. token)
				end
				for _, token in ipairs(SEMANTIC_TOKENS) do
					assert(is_hex(t.colors[token]), name .. " missing semantic token: " .. token)
				end
			end
		end)

		it("keeps the documented editorial hex values", function()
			local colors = theme.get("editorial").colors
			eq("#1a1b26", colors.background)
			eq("#f6b93b", colors.accent)
			eq("#9ece6a", colors.success)
			eq("#e0af68", colors.warning)
			eq("#f7768e", colors.error)
			eq("#7aa2f7", colors.info)
		end)

		it("shares the symbol vocabulary and border sets across palettes", function()
			local editorial = theme.get("editorial")
			for _, name in ipairs({ "phosphor", "noir" }) do
				local t = theme.get(name)
				eq(editorial.symbols, t.symbols)
				eq("soft", t.border)
				eq("comfortable", t.density)
				assert(t.borders.soft and t.borders.classic and t.borders.heavy and t.borders.editorial)
			end
		end)
	end)

	describe("monochrome fallback check", function()
		it("reports noir as monochrome and editorial/phosphor as chromatic", function()
			eq(true, theme.is_monochrome("noir"))
			eq(false, theme.is_monochrome("editorial"))
			eq(false, theme.is_monochrome("phosphor"))
		end)

		it("defaults to the active theme when given no argument", function()
			theme.set("noir")
			eq(true, theme.is_monochrome())
			theme.set("editorial")
			eq(false, theme.is_monochrome())
		end)

		it("accepts a theme table directly", function()
			eq(true, theme.is_monochrome(theme.get("noir")))
			eq(false, theme.is_monochrome(theme.get("phosphor")))
		end)

		it("errors on unknown theme names", function()
			MiniTest.expect.error(function()
				theme.is_monochrome("does-not-exist")
			end)
		end)

		it("noir keeps focus/selection/status symbols distinct without color", function()
			local symbols = theme.get("noir").symbols
			assert(symbols.focus ~= symbols.selected)
			assert(symbols.selected ~= symbols.unselected)
			assert(symbols.error ~= symbols.warning)
		end)

		it("every semantic token has a no-truecolor ansi16 fallback", function()
			theme.set("noir")
			for _, token in ipairs(SEMANTIC_TOKENS) do
				local ansi16 = Color.from_token(token):to_ansi16()
				assert(ansi16:find("\027%["))
				assert(ansi16:find("38;2", 1, true) == nil)
			end
		end)
	end)

	describe("highlight generation per palette", function()
		it("materializes the accent highlight for every palette", function()
			for _, name in ipairs({ "editorial", "phosphor", "noir" }) do
				theme.set(name)
				theme.apply_highlights()
				local hl = vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" })
				eq(hex_to_number(theme.get().colors.accent), hl.fg)
			end
		end)

		it("legacy SELECTION/BUTTON groups follow each palette accent", function()
			local highlights = require("ascii-ui.highlights")
			for _, name in ipairs({ "editorial", "phosphor", "noir" }) do
				theme.set(name)
				local sel = vim.api.nvim_get_hl(0, { name = highlights.SELECTION })
				local btn = vim.api.nvim_get_hl(0, { name = highlights.BUTTON })
				eq(hex_to_number(theme.get().colors.accent), sel.fg)
				eq(hex_to_number(theme.get().colors.accent), btn.bg)
			end
		end)
	end)

	describe("palette switching", function()
		it("resolves tokens through the active palette", function()
			theme.set("phosphor")
			eq(theme.get("phosphor").colors.accent, Color.from_token("accent").fg)
			theme.set("noir")
			eq(theme.get("noir").colors.accent, Color.from_token("accent").fg)
		end)

		it("segments consume tokens under every palette", function()
			for _, name in ipairs({ "editorial", "phosphor", "noir" }) do
				theme.set(name)
				local seg = Segment:new({ content = "hi", color = "accent" })
				eq(theme.get().colors.accent, seg.color.fg)
			end
		end)

		it("ui.setTheme switches across all three palettes", function()
			ui.setTheme("phosphor")
			eq("phosphor", ui.getTheme().name)
			ui.setTheme("noir")
			eq("noir", ui.getTheme().name)
			eq("noir", user_config.get().theme)
			ui.setTheme("editorial")
			eq("editorial", ui.getTheme().name)
		end)

		it("custom themes still inherit missing tokens from editorial", function()
			local t = theme.define({ name = "phase1-inherit", colors = { accent = "#010101" } })
			eq("#010101", t.colors.accent)
			eq(theme.get("editorial").colors.success, t.colors.success)
		end)
	end)
end)
