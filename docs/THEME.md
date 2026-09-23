# Theme System — Phase 0 Technical Design

Parent: #103 · Closes #104 · Follow-ups: #105 (tokens/palettes), #106 (interaction grammar),
#107 (borders/density), #108 (component storyboard), #109 (verification).

This document is the Phase 0 deliverable: the Lua theme object shape, public API,
inheritance/merging rules, token resolution, highlight generation, runtime switching,
and config schema — with types and API examples. Palettes beyond Editorial, the symbol
vocabulary's component integration, and storyboard verification land in later phases.

## 1. Theme object shape (`lua/ascii-ui/theme/init.lua`)

```lua
---@class ascii-ui.Theme
---@field name string
---@field colors ascii-ui.ThemeColors       -- 9 foundation + 5 semantic tokens
---@field symbols ascii-ui.ThemeSymbols     -- focus/selected/checked/status glyphs
---@field borders table<ascii-ui.BorderStyle, ascii-ui.BorderChars>
---@field border ascii-ui.BorderStyle       -- active style: soft|classic|heavy|editorial
---@field density ascii-ui.Density          -- default: compact|comfortable|spacious
```

Foundation tokens: `background, surface, elevated, border, separator, text,
text_strong, text_muted, text_disabled`. Semantic tokens: `accent, success,
warning, error, info`. The `editorial` theme is always registered and is the
fallback base (see §3).

## 2. API shape

```lua
local ui = require("ascii-ui")

ui.defineTheme({ name = "mine", colors = { accent = "#ff0000" } }) -- inherits rest from editorial
ui.setup({ theme = "mine" })                                       -- by name
ui.setup({ theme = { name = "editorial", border = "heavy" } })     -- inline ephemeral (registry untouched)
ui.setTheme("editorial")   -- runtime switch: highlights now, all mounts re-render, state preserved
ui.getTheme()              -- active theme; ui.getTheme("mine") by name
ui.theme.list()            -- registered names

local Color = require("ascii-ui.color")
Color.from_token("accent")              -- Color via active theme
Color.from_token("accent", customTheme) -- per-plugin override, global theme untouched

local useTheme = require("ascii-ui.hooks.use_theme")
local t = useTheme() -- fresh active theme on every render (no stale snapshots)
```

`Segment` consumes tokens anywhere a color is accepted:

```lua
Segment:new({ content = "Deploy", color = "accent" })              -- token
Segment:new({ content = "Deploy", color = { fg = "accent" } })     -- token in table form
Segment:new({ content = "Deploy", color = "#ff0000" })             -- hex still works
```

Unknown token names raise an error so typos fail fast instead of rendering uncolored.

## 3. Inheritance / merging rules

- `theme.define(spec)` deep-merges `spec` over `editorial`. Partial specs are
  complete themes; re-registering a name replaces it. Missing keys are never nil.
- `setup({ theme = "name" })` activates a registered theme (unknown names error).
- `setup({ theme = { ... } })` derives an **ephemeral** theme over the named (or
  current) base and activates it **without touching the registry** — inline
  experimentation can't mutate shared themes.
- `setup()` records explicit `characters`/`symbols`/`density` keys; `setTheme()`
  later re-derives theme-driven keys while preserving those overrides
  (`user_config.sync_from_theme()`).
- `Color.from_token(token, overrideTheme)` / `theme.resolve(token, overrideTheme)`
  resolve against any theme table for per-plugin personalities without changing
  the global theme.

## 4. Token resolution (`Color:to_hl_group` / `to_ansi`, fallback)

`token -> hex -> Color -> hl group / ANSI`. Truecolor ANSI via `Color:to_ansi()`
(Neovim window and `StdoutViewport` share the same tokens — stdout parity).
`Color:to_ansi16()` maps to the nearest of the 16 standard SGR colors and is the
no-truecolor fallback; `theme.supports_truecolor()` reports `termguicolors`.

## 5. Highlight generation (replaces hardcoded `highlights.lua`)

`theme.apply_highlights()` is idempotent and runs on `setup()`, `setTheme()`,
`user_config` sync, and `Window.new()`. It defines one group per token
(`AsciiUIAccent`, `AsciiUISuccess`, …) and points the legacy `SELECTION`/`BUTTON`
groups at the theme accent, so existing components theme without rewrites.
`highlights.lua` keeps the enum names for compatibility; no new hardcoded groups.

## 6. Runtime switching (`setTheme`, re-render, state preservation)

`ui.setTheme(name)` = `theme.set` (highlights refresh immediately) → config sync
(explicit overrides preserved) → `mount.rerender_all()`, which marks every
mounted fiber tree `UPDATE` and dispatches the regular `STATE_CHANGE` render path
per mount. Hook slots are untouched, so component state (counters, selections,
inputs) survives the switch. Mounts untrack on `CLOSE_WINDOW` / `WinClosed`.

## 7. Config schema (`config.lua` + `@class ascii-ui.Config`)

`theme` (name or inline spec, default `"editorial"`), `density` (default
`"comfortable"`), `symbols` (vocabulary above), `characters` (derived from the
active theme's border set unless explicitly overridden), plus existing
`log_level` / `keymaps`. Defaults = Editorial + soft + comfortable.

## Open questions for Phase 1+

- Final hex values for Phosphor / Noir palettes (#105).
- Whether `density` should also scale window padding automatically (#107).
- Auto re-render granularity (whole tree vs dirty subtrees) if profiling demands it.
