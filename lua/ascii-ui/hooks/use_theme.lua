--- Provides access to the active theme for ascii-ui components.
---
--- Unlike `useConfig` (a state snapshot), `useTheme` reads the theme registry
--- fresh on every render, so a `setTheme()` + rerender always picks up the
--- new tokens without extra subscriptions. Hook state is preserved across
--- theme switches because switching never touches fiber hook slots.
---
--- @return ascii-ui.Theme theme the currently active theme
local useTheme = function()
	local theme = require("ascii-ui.theme")
	return theme.get()
end

return useTheme
