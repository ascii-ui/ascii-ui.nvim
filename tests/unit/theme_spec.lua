local Color = require("ascii-ui.color")
local Segment = require("ascii-ui.buffer.segment")
local createComponent = require("ascii-ui.components.create-component")
local fiber = require("ascii-ui.fiber")
local theme = require("ascii-ui.theme")
local ui = require("ascii-ui")
local useState = require("ascii-ui.hooks.use_state")
local useTheme = require("ascii-ui.hooks.use_theme")
local user_config = require("ascii-ui.config.user_config")

local eq = require("tests.assertions").eq

---@param bufnr integer
---@param pattern string plain-text pattern to wait for
---@return boolean found within timeout
local function wait_for_buffer(bufnr, pattern)
	return vim.wait(2000, function()
		local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
		if not ok then
			return false
		end
		return vim.iter(lines):join("\n"):find(pattern, 1, true) ~= nil
	end)
end

---@param bufnr integer
local function close_window(bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win ~= -1 then
		vim.api.nvim_win_close(win, true)
	end
end

describe("theme (Phase 0 technical design)", function()
	before_each(function()
		theme.reset()
		user_config.set({})
	end)

	describe("theme object shape", function()
		it("editorial is registered by default", function()
			assert(vim.tbl_contains(theme.list(), "editorial"))
		end)

		it("exposes foundation and semantic color tokens", function()
			local t = theme.get("editorial")
			for _, token in ipairs({
				"background",
				"surface",
				"elevated",
				"border",
				"separator",
				"text",
				"text_strong",
				"text_muted",
				"text_disabled",
				"accent",
				"success",
				"warning",
				"error",
				"info",
			}) do
				assert(t.colors[token], "missing token: " .. token)
			end
		end)

		it("exposes symbols, borders, border style and density", function()
			local t = theme.get("editorial")
			eq(">", t.symbols.focus)
			eq("soft", t.border)
			eq("comfortable", t.density)
			assert(t.borders.soft)
			assert(t.borders.classic)
			assert(t.borders.heavy)
			assert(t.borders.editorial)
		end)
	end)

	describe("defineTheme / inheritance", function()
		it("custom themes inherit missing tokens from editorial", function()
			local t = theme.define({ name = "custom-inherit", colors = { accent = "#ffffff" } })
			eq("#ffffff", t.colors.accent)
			eq(theme.get("editorial").colors.success, t.colors.success)
		end)

		it("requires a name", function()
			MiniTest.expect.error(function()
				theme.define({ colors = {} })
			end)
		end)

		it("registers the theme under its name", function()
			theme.define({ name = "custom-reg", colors = { accent = "#111111" } })
			assert(vim.tbl_contains(theme.list(), "custom-reg"))
		end)
	end)

	describe("public API shape", function()
		it("exposes ui.theme, ui.defineTheme, ui.setTheme, ui.getTheme", function()
			assert(ui.theme)
			assert(type(ui.defineTheme) == "function")
			assert(type(ui.setTheme) == "function")
			assert(type(ui.getTheme) == "function")
		end)

		it("setup({ theme = name }) selects a registered theme", function()
			ui.setup({ theme = "editorial" })
			eq("editorial", ui.getTheme().name)
		end)

		it("setup({ theme = table }) selects an inline theme", function()
			ui.setup({ theme = { name = "editorial", colors = { accent = "#123456" } } })
			eq("#123456", ui.getTheme().colors.accent)
		end)

		it("setup rejects an unknown theme name", function()
			MiniTest.expect.error(function()
				ui.setup({ theme = "does-not-exist" })
			end)
		end)
	end)

	describe("merging rules", function()
		it("partial characters override wins over theme border chars", function()
			ui.setup({ characters = { top_left = "X" } })
			local chars = user_config.get().characters
			eq("X", chars.top_left)
			eq(theme.get("editorial").borders.soft.top_right, chars.top_right)
		end)

		it("theme border style drives characters when no override given", function()
			ui.setup({ theme = { name = "editorial", border = "heavy" } })
			eq(theme.get().borders.heavy.top_left, user_config.get().characters.top_left)
		end)

		it("partial symbols and density overrides win over theme defaults", function()
			ui.setup({ symbols = { focus = "»" }, density = "compact" })
			eq("»", user_config.get().symbols.focus)
			eq("compact", user_config.get().density)
		end)

		it("per-plugin override resolves without touching the global theme", function()
			local plugin_theme = theme.define({ name = "plugin-theme", colors = { accent = "#010101" } })
			eq("#010101", theme.resolve("accent", plugin_theme))
			eq("editorial", theme.get().name)
		end)
	end)

	describe("token resolution", function()
		it("Color.from_token resolves to the active theme color", function()
			local c = Color.from_token("accent")
			assert(Color.is_color(c))
			eq(theme.get().colors.accent, c.fg)
		end)

		it("Color.from_token errors on unknown tokens", function()
			MiniTest.expect.error(function()
				Color.from_token("nope-not-a-token")
			end)
		end)

		it("Segment consumes theme tokens", function()
			local seg = Segment:new({ content = "hi", color = "accent" })
			eq(theme.get().colors.accent, seg.color.fg)
		end)

		it("Segment still accepts hex strings", function()
			local seg = Segment:new({ content = "hi", color = "#ff0000" })
			eq("#ff0000", seg.color.fg)
		end)

		it("resolved tokens produce both hl groups and ANSI (stdout parity)", function()
			local c = Color.from_token("accent")
			assert(c:to_hl_group():find("AsciiUI"))
			assert(c:to_ansi():find("\027%[38;2;"))
		end)

		it("no-truecolor fallback maps to 16-color SGR codes", function()
			local ansi16 = Color.new("#ff0000"):to_ansi16()
			assert(ansi16:find("\027%["))
			assert(ansi16:find("38;2", 1, true) == nil)
		end)

		it("supports_truecolor returns a boolean", function()
			assert(type(theme.supports_truecolor()) == "boolean")
		end)
	end)

	describe("highlight generation", function()
		it("apply_highlights defines stable per-token groups", function()
			theme.apply_highlights()
			local hl = vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" })
			assert(hl.fg or hl.background)
		end)

		it("legacy SELECTION/BUTTON groups follow the theme accent", function()
			theme.apply_highlights()
			local highlights = require("ascii-ui.highlights")
			local sel = vim.api.nvim_get_hl(0, { name = highlights.SELECTION })
			local btn = vim.api.nvim_get_hl(0, { name = highlights.BUTTON })
			assert(sel.fg)
			assert(btn.bg)
		end)

		it("re-applying highlights is idempotent", function()
			theme.apply_highlights()
			local first = vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" })
			theme.apply_highlights()
			eq(first, vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" }))
		end)
	end)

	describe("runtime switching", function()
		it("setTheme redefines highlight groups without re-render", function()
			theme.apply_highlights()
			local before = vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" })
			theme.define({ name = "switched", colors = { accent = "#010203" } })
			theme.set("switched")
			local after = vim.api.nvim_get_hl(0, { name = "AsciiUIAccent" })
			MiniTest.expect.no_equality(before, after)
			eq("switched", theme.get().name)
		end)

		it("fiber rerender after setTheme preserves hook state", function()
			local Counter = createComponent("ThemeSwitchCounter", function()
				local count = useState(41)
				local t = useTheme()
				return {
					Segment:new({ content = "count=" .. count .. " accent=" .. t.colors.accent }):wrap(),
				}
			end, {})

			local root = fiber.render(Counter)
			local before = root:get_buffer():to_lines()[1]
			assert(before:find("count=41", 1, true))

			theme.define({ name = "rerender-theme", colors = { accent = "#0a0b0c" } })
			theme.set("rerender-theme")
			-- same marking mount.rerender_all() performs before the state-change render
			root:reset()
			for node in root:iter() do
				node.tag = "UPDATE"
			end
			root = fiber.rerender(root)
			local after = root:get_buffer():to_lines()[1]
			assert(after:find("count=41", 1, true))
			assert(after:find("#0a0b0c", 1, true))
		end)

		it("ui.setTheme re-renders mounted trees with state preserved", function()
			local Themed = createComponent("ThemeSwitchMounted", function()
				local count = useState(7)
				local t = useTheme()
				return {
					Segment:new({ content = "n=" .. count .. " a=" .. t.colors.accent }):wrap(),
				}
			end, {})
			theme.define({ name = "live-switch", colors = { accent = "#112233" } })

			local bufnr = ui.mount(Themed)
			assert(wait_for_buffer(bufnr, "#f6b93b"))

			ui.setTheme("live-switch")
			assert(wait_for_buffer(bufnr, "#112233"))
			assert(wait_for_buffer(bufnr, "n=7"))

			close_window(bufnr)
		end)
	end)

	describe("config schema", function()
		it("defaults to Editorial + soft + comfortable", function()
			local defaults = require("ascii-ui.config")
			eq("editorial", defaults.theme)
			eq("comfortable", defaults.density)
			eq(">", defaults.symbols.focus)
			eq("╭", defaults.characters.top_left)
		end)

		it("useTheme returns the active theme fresh on each render", function()
			eq("editorial", useTheme().name)
			theme.define({ name = "fresh-check", colors = {} })
			theme.set("fresh-check")
			eq("fresh-check", useTheme().name)
		end)
	end)
end)
