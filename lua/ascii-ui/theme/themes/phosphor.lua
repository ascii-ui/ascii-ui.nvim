--- Phosphor palette: green-phosphor terminal personality.
---
--- Near-black green-tinted surfaces with a phosphor-green accent. Warning
--- stays amber (classic amber-terminal nod) while error/info keep their
--- semantic hues so status stays scannable without component rewrites.
---@type ascii-ui.ThemeSpec
return {
	name = "phosphor",
	colors = {
		background = "#0a0f0a",
		surface = "#0f1a0f",
		elevated = "#172417",
		border = "#2d5a2d",
		separator = "#1e3a1e",
		text = "#b8e6b8",
		text_strong = "#eaffea",
		text_muted = "#5f8a5f",
		text_disabled = "#385438",
		accent = "#33ff66",
		success = "#33ff66",
		warning = "#ffcc33",
		error = "#ff5555",
		info = "#55ffff",
	},
	border = "soft",
	density = "comfortable",
}
