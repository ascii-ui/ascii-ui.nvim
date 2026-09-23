--- Legacy highlight group names kept for backward compatibility.
---
--- These groups are now managed by the theme system: `theme.apply_highlights()`
--- (called by `setup()`, `setTheme()` and `Window.new()`) points them at the
--- active theme's tokens, and additionally defines one group per color token
--- (`AsciiUIAccent`, `AsciiUISuccess`, ...). Do not hardcode new groups here;
--- add a theme token instead.
---@enum (key) ascii-ui.Highlights
local Highlights = {
	DEFAULT = "AsciiUIDefault",
	SELECTION = "AsciiUISelection",
	BUTTON = "AsciiUIButton",
}

return Highlights
