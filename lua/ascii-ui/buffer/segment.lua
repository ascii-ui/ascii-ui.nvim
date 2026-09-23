local Color = require("ascii-ui.color")
local interaction_type = require("ascii-ui.interaction_type")

--- @class ascii-ui.InputCallbacks
--- @field state_setter fun(value: string) Sets the Input component's internal state
--- @field on_change? fun(value: string) Fires on every text change
--- @field on_submit? fun(value: string) Fires on <CR> in insert mode
--- @field on_blur? fun(value: string) Fires on exit insert mode

--- @class ascii-ui.SegmentOpts
--- @field content string does not support newlines
--- @field is_focusable? boolean whether the segment can be focused
--- @field interactions? table<ascii-ui.UserInteractions.InteractionType, function> a map of interaction types to functions
--- @field highlight? string a highlight group name to apply to the segment
--- @field color? string | ascii-ui.SegmentColor | ascii-ui.Color hex string shorthand ("#rrggbb"), theme token ("accent"), table {fg, bg}, or Color instance
--- @field _input_callbacks? ascii-ui.InputCallbacks imperative callbacks for Input component (set by Input, read by mount autocmds)

---
--- A segment is the minimal unit of a render in ascii-ui.
--- It contains the content to be displayed, optional interactions, and can be highlighted.
---@class ascii-ui.Segment
---@field content string
---@field interactions table<ascii-ui.UserInteractions.InteractionType, function>
---@field highlight? string
---@field color? ascii-ui.Color normalized to Color instance
---@field _input_callbacks? ascii-ui.InputCallbacks imperative callbacks for Input component
---@field private focusable boolean
local Segment = {}
Segment.__index = Segment

local last_incremental_id = 0
local function generate_id()
	last_incremental_id = last_incremental_id + 1
	return last_incremental_id
end

local function unicode_len(s)
	local i, len = 1, 0
	while i <= #s do
		local c = s:byte(i)
		if c < 0x80 then
			i = i + 1
		elseif c < 0xE0 then
			i = i + 2
		elseif c < 0xF0 then
			i = i + 3
		else
			i = i + 4
		end
		len = len + 1
	end
	return len
end

--- Returns true when `s` parses as a `#rgb` / `#rrggbb` hex color.
---@param s any
---@return boolean
local function is_hex_string(s)
	if type(s) ~= "string" then
		return false
	end
	local clean = s:gsub("^#", "")
	return (#clean == 3 or #clean == 6) and clean:match("^[0-9a-fA-F]+$") ~= nil
end

--- Normalize the color field to a Color instance.
--- Accepts:
---   - nil → nil
---   - string "#rrggbb" → Color instance with fg
---   - string token name (e.g. `"accent"`) → Color resolved via the active theme
---   - table { fg, bg } → Color instance (fg/bg also accept token names)
---   - Color instance → same instance (cached)
--- Unknown token names raise an error so typos fail fast.
---@param color string | ascii-ui.SegmentColor | ascii-ui.Color | nil
---@return ascii-ui.Color | nil
local function normalize_color(color)
	if color == nil then
		return nil
	end
	if type(color) == "string" and not is_hex_string(color) then
		return Color.from_token(color)
	end
	if type(color) == "table" and not Color.is_color(color) then
		local fg, bg = color.fg, color.bg
		if type(fg) == "string" and not is_hex_string(fg) then
			fg = require("ascii-ui.theme").resolve(fg)
		end
		if type(bg) == "string" and not is_hex_string(bg) then
			bg = require("ascii-ui.theme").resolve(bg)
		end
		return Color.new({ fg = fg, bg = bg })
	end
	return Color.new(color)
end

---@param ... ascii-ui.SegmentOpts  | string
---@return ascii-ui.Segment
function Segment:new(...)
	local props = { ... }

	if type(props[1]) == "string" then
		props = { content = props[1], is_focusable = props[2], interactions = props[3], highlight = props[4] }
	else
		props = props[1]
	end
	assert(type(props) == "table", "Segment props must be a table. Found: " .. type(props) .. " " .. debug.traceback())

	vim.validate({ content = { props.content, "string" } })

	-- content cannot have newlines
	assert(not props.content:find("\n", 1, true), "Segment content cannot contain newlines. Found: " .. props.content)

	local state = {
		id = generate_id(),
		content = props.content,
		highlight = props.highlight,
		color = normalize_color(props.color),
		focusable = props.is_focusable or false,
		interactions = props.interactions or {},
		_input_callbacks = props._input_callbacks,
	}

	setmetatable(state, self)

	return state
end

--- @param obj any
function Segment.is_segment(obj)
	if
		type(obj) == "table"
		--
		and obj.__index == Segment.__index
	then
		return true
	end

	return false
end

---@return integer
function Segment:len()
	return unicode_len(self.content)
end

---@return integer
function Segment:raw_len()
	return string.len(self.content)
end

function Segment:to_string()
	return self.content
end

---@return boolean
function Segment:is_focusable()
	if self.focusable then
		return true
	end

	return vim.tbl_count(self.interactions) > 0
end

function Segment:is_colored()
	if self.highlight then
		return true
	end

	if self.color and (self.color.bg or self.color.fg) then
		return true
	end

	return false
end

function Segment:is_inputable()
	return self.interactions[interaction_type.INPUT] ~= nil
end

--- Returns the input callbacks if this segment is an Input component.
--- @return ascii-ui.InputCallbacks | nil
function Segment:get_input_callbacks()
	return self._input_callbacks
end

--- Wraps the segment in a ascii-ui.Bufferline object
---@return ascii-ui.BufferLine
function Segment:wrap()
	local Bufferline = require("ascii-ui.buffer.bufferline")
	return Bufferline.new(self)
end

return Segment
