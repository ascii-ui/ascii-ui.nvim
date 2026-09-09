<img align="right" width="100px" src="./logo.png" alt="Ascii-UI Logo" />

[![Test](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/test.yml)
[![Lux Publish](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/publish-to-luarocks.yml/badge.svg)](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/publish-to-luarocks.yml)
[![Docs](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/check-docs.yml/badge.svg)](https://github.com/ascii-ui/ascii-ui.nvim/actions/workflows/check-docs.yml)

# ascii-ui.nvim

**Build rich, interactive Neovim plugin UIs with React-like components, hooks, and a fiber-based reconciler.**

Instead of juggling `nvim_buf_set_lines`, highlight namespaces, and manual redraws, you describe your UI as functional components. ascii-ui.nvim renders it to a floating window or stdout, diffs the tree, and updates only what changed.

## The Problem

Building even a simple interactive UI in Neovim today means wiring together low-level APIs:

- Create a buffer, set lines, add highlights
- Track window IDs and buffer numbers
- Re-render manually every time state changes
- Handle focus, keymaps, and cleanup yourself

A counter that should take a few lines quickly becomes a tangle of buffer and window management.

## The Solution

ascii-ui.nvim brings a React-like model to Neovim plugin development:

```lua
local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local Button = ui.components.Button
local useState = ui.hooks.useState

local Counter = ui.createComponent("Counter", function()
    local count, setCount = useState(0)
    return {
        Paragraph({ content = "Count: " .. count }),
        Button({
            label = "+1",
            on_press = function()
                setCount(count + 1)
            end,
        }),
    }
end)

ui.mount(Counter)
```

That is the whole component. State, rendering, diffing, and input are handled for you.

## Quick Start

### 1. Install

**Built-in Neovim packages:**

```bash
git clone https://github.com/ascii-ui/ascii-ui.nvim.git \
  ~/.config/nvim/pack/plugins/start/ascii-ui.nvim
```

**[lazy.nvim](https://github.com/folke/lazy.nvim):**

```lua
return {
    "ascii-ui/ascii-ui.nvim",
    opts = {},
}
```

**[lux](https://github.com/lux-cli/lux):**

```bash
lux install ascii-ui
```

**[luarocks](https://luarocks.org/):**

```bash
luarocks install ascii-ui
```

### 2. Create a component

Save this as `lua/my-counter.lua` (or paste it into your config):

```lua
local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local Button = ui.components.Button
local useState = ui.hooks.useState

return ui.createComponent("Counter", function()
    local count, setCount = useState(0)
    return {
        Paragraph({ content = "Count: " .. count }),
        Button({
            label = "+1",
            on_press = function()
                setCount(count + 1)
            end,
        }),
    }
end)
```

### 3. Mount it

From anywhere in Neovim:

```lua
local Counter = require("my-counter")
require("ascii-ui").mount(Counter)
```

A floating window opens, and pressing the button updates the count instantly.

## Example Output

The counter above renders in a floating window like this:

```
╭──────────────╮
│ Count: 0     │
│ [ +1 ]       │
╰──────────────╯
```

Press `<CR>` on the button and the count updates without you touching the buffer API.

## Features

- **React-like component model** — functional components with props, composition, and reconciliation
- **Hooks** — `useState`, `useEffect`, `useReducer`, `useInterval`, `useTimeout`, `useConfig`
- **Built-in components** — Button, Input, Select, Slider, Checkbox, Tree, Box, Paragraph
- **Layout primitives** — `Row` and `Column` for horizontal and vertical arrangement
- **Fiber-based reconciler** — efficient tree diffing and minimal re-renders
- **Multiple viewports** — Neovim floating windows (default), terminal stdout, or custom
- **Live reload** — instant feedback during development with `make debug`
- **ANSI truecolor** — full color support via the `Color` class and segment colors
- **Zero dependencies** — pure Lua, runs on Neovim's embedded Lua 5.1

## What Can You Build?

<table align="center">
  <tr>
    <td><img src="https://github.com/user-attachments/assets/0d2729e1-1518-430f-93f1-e52755b6f347" height="250"></td>
    <td><img src="https://github.com/user-attachments/assets/1df3c920-0ced-46a0-90c7-97231ad33ba9" height="250"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/419ab99a-424a-46e5-bc1c-8f177cbef298" height="250"></td>
    <td><img src="https://github.com/user-attachments/assets/1e9ecc74-9e1a-4e67-b3c1-9d04b5c4755e" height="250"></td>
  </tr>
</table>

From file explorers and dashboards to animated clocks and train station boards — if it can be drawn with text, ascii-ui.nvim can render it.

See the [`examples/`](./examples/) directory for more:

| Example | What it shows |
|---------|--------------|
| [`analog-clock.lua`](./examples/analog-clock.lua) | Animated clock with `useInterval` + `Color` |
| [`file_structure.lua`](./examples/file_structure.lua) | Collapsible tree with the `Tree` component |
| [`train-station-board.lua`](./examples/train-station-board.lua) | Scrolling text animation |
| [`animated-bar-chart.lua`](./examples/animated-bar-chart.lua) | Dynamic bar chart with state |
| [`metro-map.lua`](./examples/metro-map.lua) | ASCII art with colored segments |
| [`text-input.lua`](./examples/text-input.lua) | Form with `Input` component |
| [`select-dropdown.lua`](./examples/select-dropdown.lua) | Selectable list with `Select` |

## Documentation

| Guide | Description |
|-------|-------------|
| [**Components**](./docs/COMPONENTS.md) | Full reference for all built-in components with props and examples |
| [**Hooks**](./docs/HOOKS.md) | State management, side effects, timers — the full hooks API |
| [**Layout**](./docs/LAYOUT.md) | `Row` and `Column` for arranging components |
| [**Advanced**](./docs/ADVANCED.md) | Custom components, viewports, low-level rendering (Segment, BufferLine, Buffer) |
| [**API Reference**](https://ascii-ui.github.io/) | Full generated documentation |

## Configuration

```lua
require("ascii-ui").setup({
    log_level = "INFO",
    characters = {
        top_left = "╭", top_right = "╮",
        bottom_left = "╰", bottom_right = "╯",
        horizontal = "─", vertical = "│",
        left_tree = "├", thumb = "●",
        whitespace = " ", right_triangule = "▸", down_triangule = "▾",
    },
    keymaps = {
        quit = "q",
        select = "<CR>",
    },
})
```

## Live Reload

ascii-ui.nvim ships a live-reload debug mode. Save any `.lua` file and the running Neovim instance automatically tears down the current UI, unloads all modules, and re-executes your script.

**Requirements:** `nvim` on `$PATH`.

### Quick start

1. Write your component in any `.lua` file and return it:

```lua
-- lua/myplugin/MyComp.lua
local ui = require("ascii-ui")
local useState = ui.hooks.useState
local Paragraph = ui.components.Paragraph
local Button = ui.components.Button

return ui.createComponent("MyComp", function()
    local count, setCount = useState(0)
    return {
        Paragraph({ content = "count: " .. count }),
        Button({ label = "+1", on_press = function() setCount(count + 1) end }),
    }
end)
```

2. Create a `debug.lua` in the repository root:

```lua
require("ascii-ui").debug("lua/myplugin/MyComp.lua")
```

3. Start the session:

```sh
make debug
```

Every save reloads the UI automatically. Errors are shown as notifications without crashing the session.

Works from any running Neovim session too:

```
:lua require("ascii-ui").debug("lua/myplugin/MyComp.lua")
```

## AI Agent Skill

Use ascii-ui.nvim with AI coding agents (OpenCode, Claude, etc.) by installing the official agent skill:

```sh
npx skills add ascii-ui/agent-skills --skill ascii-ui-nvim
```

The skill gives agents a mental model of the component system, hooks, and common patterns so they can generate correct ascii-ui code without hallucinating APIs. Source: [ascii-ui/agent-skills](https://github.com/ascii-ui/agent-skills).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development setup, commit conventions, and how to add components or hooks.

## License

MIT
