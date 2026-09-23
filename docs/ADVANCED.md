# Advanced Guide

This guide covers the lower-level APIs for building custom components, creating custom viewports, and working directly with rendering primitives.

## Custom Components

### createComponent

Every component is created with `ui.createComponent`. It registers the component, validates props, and integrates with the fiber reconciler.

```lua
local ui = require("ascii-ui")

-- Minimal form (anonymous component)
local MyComponent = ui.createComponent(function(props)
    return { ui.components.Paragraph({ content = "Hello" }) }
end)

-- Named form with prop types
local MyComponent = ui.createComponent("MyComponent", function(props)
    return { ui.components.Paragraph({ content = props.message }) }
end, { message = "string" })
```

### Signature

```lua
---@param name string                          -- component name (for debugging)
---@param fn fun(props: table): FiberNode[]    -- render function
---@param types? table<string, PropsType>      -- prop type declarations
---@return FunctionalComponent
```

### Prop Type Validation

The third argument declares expected prop types. Invalid types raise errors at call time:

```lua
local MyComponent = ui.createComponent("MyComponent", function(props)
    -- props.name is guaranteed to be a string (if provided)
    -- props.count is guaranteed to be a number (if provided)
    return {}
end, {
    name = "string",
    count = "number",
    active = "boolean",
    on_change = "function",
    items = "table",
})
```

Valid types: `"string"`, `"number"`, `"boolean"`, `"function"`, `"table"`, `"nil"`.

### Extended Format

For components that need layout configuration:

```lua
local MyComponent = ui.createComponent("MyComponent", fn, {
    props = { text = "string" },
    layout = { direction = "row" },
})
```

---

## Rendering Primitives

At the lowest level, components return arrays of `BufferLine` objects. Each `BufferLine` contains one or more `Segment` objects.

### Segment

A `Segment` is the minimal unit of rendered text. It holds content, styling, and interaction handlers.

```lua
local Segment = require("ascii-ui.buffer.segment")

-- Basic segment
local seg = Segment:new({ content = "Hello" })

-- With highlight group
local seg = Segment:new({
    content = "Warning!",
    highlight = "DiagnosticWarn",
})

-- With truecolor
local seg = Segment:new({
    content = "Colored text",
    color = "#ff6600",
})

-- Focusable + interactive
local seg = Segment:new({
    content = "[Click me]",
    is_focusable = true,
    interactions = {
        [interaction_type.SELECT] = function()
            print("Clicked!")
        end,
    },
})
```

#### Segment Options

| Field | Type | Description |
|-------|------|-------------|
| `content` | `string` | Text content (no newlines). |
| `is_focusable` | `boolean\|nil` | Whether the segment can receive focus. |
| `interactions` | `table\|nil` | Map of interaction types to callback functions. |
| `highlight` | `string\|nil` | Neovim highlight group name. |
| `color` | `string\|Color\|nil` | Truecolor: hex string `"#rrggbb"`, table `{fg, bg}`, or `Color` instance. |

#### Wrapping in BufferLine

Segments must be wrapped in a `BufferLine` to be returned from a component:

```lua
local line = seg:wrap()  -- Returns a BufferLine containing this segment
```

### BufferLine

A `BufferLine` is a horizontal line composed of one or more segments.

```lua
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")

-- Single segment
local line = Segment:new({ content = "Hello" }):wrap()

-- Multiple segments on one line
local line = BufferLine.new(
    Segment:new({ content = "Name: " }),
    Segment:new({ content = "John", color = "#00ff00" }),
    Segment:new({ content = " | " }),
    Segment:new({ content = "Age: 30", color = "#0088ff" })
)
```

### Buffer

A `Buffer` is a collection of `BufferLine` objects representing a complete frame.

```lua
local Buffer = require("ascii-ui.buffer.buffer")
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")

local buffer = Buffer.new()
buffer:add(BufferLine.new(Segment:new({ content = "Line 1" })))
buffer:add(BufferLine.new(Segment:new({ content = "Line 2" })))
```

---

## Color API

The `Color` class provides truecolor support for segments.

```lua
local ui = require("ascii-ui")

-- String shorthand (foreground only)
local red = ui.Color.new("#ff0000")

-- Table form (foreground + background)
local styled = ui.Color.new({ fg = "#ffffff", bg = "#333333" })

-- Use with segments
local seg = ui.blocks.Segment({
    content = "Styled text",
    color = red,
})

-- Or use hex string directly
local seg2 = ui.blocks.Segment({
    content = "More styled text",
    color = "#00ff88",
})
```

### Color Methods

```lua
local color = ui.Color.new({ fg = "#ff0000", bg = "#000000" })

color:to_ansi()           -- ANSI truecolor escape sequence
color:to_highlight_group() -- Neovim highlight group name (cached)
```

---

## Custom Viewports

A viewport is any object that implements the `ascii-ui.Viewport` interface. Pass it as the second argument to `ui.mount`.

### Viewport Interface

```lua
---@class ascii-ui.Viewport
---@field open       fun(self)
---@field close      fun(self)
---@field update     fun(self, buffer: Buffer)
---@field is_focused fun(self): boolean
---@field enable_edits  fun(self)
---@field disable_edits fun(self)
---@field get_id     fun(self): integer
---@field get_bufnr  fun(self): integer
---@field get_ns_id  fun(self): integer
```

### Built-in Viewports

| Viewport | Description | Usage |
|----------|-------------|-------|
| `Window` (default) | Centered Neovim floating window | `ui.mount(Component)` |
| `StdoutViewport` | Terminal stdout with ANSI colors | `ui.mount(Component, ui.viewports.StdoutViewport.new())` |

### Custom Window Dimensions

```lua
local Window = require("ascii-ui.window")

local win = Window.new({ width = 80, height = 24 })
ui.mount(MyComponent, win)
```

### StdoutViewport

Renders to terminal stdout using ANSI truecolor escape codes. Useful for headless scripts, CI pipelines, or terminal animations.

```lua
local ui = require("ascii-ui")

local viewport = ui.viewports.StdoutViewport.new()
ui.mount(MyComponent, viewport)
```

**Custom writer** (for testing or piping):
```lua
local lines = {}
local viewport = ui.viewports.StdoutViewport.new(function(s)
    table.insert(lines, s)
end)
ui.mount(MyComponent, viewport)
```

### Implementing a Custom Viewport

```lua
local ui = require("ascii-ui")

---@class MyViewport : ascii-ui.Viewport
local MyViewport = {}
MyViewport.__index = MyViewport

function MyViewport.new()
    return setmetatable({}, MyViewport)
end

function MyViewport:open()
    -- Initialize your rendering target
end

function MyViewport:close()
    -- Clean up resources
end

function MyViewport:update(buffer)
    -- Called every frame with the rendered buffer
    -- buffer:to_lines() returns string[]
    -- buffer:iter_colored_segments() for colored segments
    for _, line in ipairs(buffer:to_lines()) do
        -- Write line to your target
    end
end

function MyViewport:is_focused()
    return false
end

function MyViewport:enable_edits() end
function MyViewport:disable_edits() end
function MyViewport:get_id() return -1 end
function MyViewport:get_bufnr() return -1 end
function MyViewport:get_ns_id() return -1 end

-- Usage:
ui.mount(MyComponent, MyViewport.new())
```

---

## Building a Component from Scratch

Here's a complete example of a custom component using low-level primitives:

```lua
local ui = require("ascii-ui")
local Segment = require("ascii-ui.buffer.segment")
local BufferLine = require("ascii-ui.buffer.bufferline")
local interaction_type = require("ascii-ui.interaction_type")
local useState = ui.hooks.useState

local ToggleButton = ui.createComponent("ToggleButton", function(props)
    local active, setActive = useState(false)

    local label = active and "[ON]" or "[OFF]"
    local color = active and "#00ff00" or "#ff0000"

    return {
        BufferLine.new(
            Segment:new({
                content = label,
                color = color,
                is_focusable = true,
                interactions = {
                    [interaction_type.SELECT] = function()
                        setActive(not active)
                        if props.on_toggle then
                            props.on_toggle(not active)
                        end
                    end,
                },
            })
        ),
    }
end, {
    on_toggle = "function",
})

-- Usage:
local App = ui.createComponent("App", function()
    return {
        ToggleButton({
            on_toggle = function(state)
                print("Toggled to: " .. tostring(state))
            end,
        }),
    }
end)

ui.mount(App)
```

---

## Interaction Types

Segments can respond to user interactions. Available interaction types:

| Type | Trigger | Description |
|------|---------|-------------|
| `SELECT` | `<CR>` on focused segment | Primary activation (button press, toggle) |
| `CURSOR_MOVE_LEFT` | `<Left>` on focused segment | Move left (slider decrease) |
| `CURSOR_MOVE_RIGHT` | `<Right>` on focused segment | Move right (slider increase) |
| `INPUT` | Insert mode entry | Marks segment as inputable |

```lua
local interaction_type = require("ascii-ui.interaction_type")

Segment:new({
    content = "Interactive",
    is_focusable = true,
    interactions = {
        [interaction_type.SELECT] = function() print("Selected!") end,
        [interaction_type.CURSOR_MOVE_LEFT] = function() print("Left!") end,
        [interaction_type.CURSOR_MOVE_RIGHT] = function() print("Right!") end,
    },
})
```

---

## Debug Mode

Use `ui.debug()` for live-reload development:

```lua
-- Load and mount a component file with auto-reload on save
require("ascii-ui").debug("lua/myplugin/MyComponent.lua")
```

The debug function:
1. Loads the file with `dofile()`
2. Mounts the returned component
3. Registers a `BufWritePost` autocmd to reload on save
4. Shows errors as notifications without crashing

---

## Testing

ascii-ui.nvim provides testing utilities:

```lua
local testing = require("ascii-ui.testing")
```

Unit tests use mini.test's Busted-style harness:

```lua
local eq = require("tests.assertions").eq

describe("MyComponent", function()
    it("renders correctly", function()
        -- Test your component logic
    end)
end)
```

Run tests with:
```bash
make test                              # Full suite
make test tests/unit/my_spec.lua       # Single file
```
