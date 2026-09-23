--- Noir palette: strict monochrome personality.
---
--- Every token is grayscale (`r == g == b`), so `theme.is_monochrome("noir")`
--- holds. Focus, selection and status semantics survive without color because
--- they are carried by the symbol vocabulary (`>`, `●`/`○`, `✓`/`×`/`!`) and
--- text contrast — never by hue alone.
---@type ascii-ui.ThemeSpec
return {
	name = "noir",
	colors = {
		background = "#0a0a0a",
		surface = "#161616",
		elevated = "#232323",
		border = "#454545",
		separator = "#2e2e2e",
		text = "#d4d4d4",
		text_strong = "#ffffff",
		text_muted = "#8a8a8a",
		text_disabled = "#5c5c5c",
		accent = "#ffffff",
		success = "#d9d9d9",
		warning = "#a6a6a6",
		error = "#f2f2f2",
		info = "#c2c2c2",
	},
	border = "soft",
	density = "comfortable",
}
