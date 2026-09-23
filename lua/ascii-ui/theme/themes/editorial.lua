--- Terminal Editorial palette (default theme).
---
--- Warm dark editorial look: deep ink backgrounds, soft periwinkle text and a
--- golden accent. This is the fallback base every custom theme inherits from
--- (see `ascii-ui.theme.define`), so its token map must stay complete.
---@type ascii-ui.ThemeSpec
return {
	name = "editorial",
	colors = {
		background = "#1a1b26",
		surface = "#24283b",
		elevated = "#2f3549",
		border = "#414868",
		separator = "#343b5c",
		text = "#c0caf5",
		text_strong = "#ffffff",
		text_muted = "#787c99",
		text_disabled = "#565f89",
		accent = "#f6b93b",
		success = "#9ece6a",
		warning = "#e0af68",
		error = "#f7768e",
		info = "#7aa2f7",
	},
	border = "soft",
	density = "comfortable",
}
