# Hooks Guide

Hooks let you add state and side effects to functional components. They follow React's hook model — call them at the top level of your component function, and the framework manages the lifecycle.

All hooks are accessed via `ui.hooks.<name>`.

## useState

Local state management. Returns the current value and a setter function. Calling the setter triggers a re-render.

```lua
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
```

### Signature

```lua
---@generic T
---@param initial T
---@return T value          -- current state (deep copy)
---@return fun(v: T | fun(prev: T): T) setValue
```

### Setter Behavior

The setter accepts either a new value or a function that receives the previous value:

```lua
-- Direct value
setCount(42)

-- Functional update (receives previous value)
setCount(function(prev)
    return prev + 1
end)
```

### Key Details

- State is **per-component-instance** — each mount gets its own state
- The returned value is a **deep copy** — mutating it won't trigger re-renders
- If the new value equals the old value (`==`), no re-render occurs
- Works with any Lua type: numbers, strings, tables, booleans, nil

### Common Patterns

**Toggle:**
```lua
local is_open, set_open = useState(false)
Button({
    label = is_open and "Close" or "Open",
    on_press = function() set_open(not is_open) end,
})
```

**Accumulator:**
```lua
local total, setTotal = useState(0)
Button({
    label = "Add 10",
    on_press = function()
        setTotal(function(prev) return prev + 10 end)
    end,
})
```

**Object state:**
```lua
local form, setForm = useState({ name = "", email = "" })
Input({
    value = form.name,
    on_change = function(v)
        setForm(function(prev)
            prev.name = v
            return prev
        end)
    end,
})
```

---

## useEffect

Runs side effects after render. Optionally re-runs when dependencies change.

```lua
local useEffect = ui.hooks.useEffect
local useState = ui.hooks.useState

local Logger = ui.createComponent("Logger", function()
    local count, setCount = useState(0)

    useEffect(function()
        print("Count changed to: " .. count)
        -- Optional: return a cleanup function
        return function()
            print("Cleaning up...")
        end
    end, { count })

    return {
        Paragraph({ content = "Count: " .. count }),
        Button({
            label = "+1",
            on_press = function() setCount(count + 1) end,
        }),
    }
end)
```

### Signature

```lua
---@param fn fun(): function|nil   -- effect function, optionally returns cleanup
---@param dependencies? any[]      -- re-run when any value changes
```

### Dependency Behavior

| Dependencies | Behavior |
|-------------|----------|
| Not provided | Runs after **every** render |
| `{}` (empty) | Runs **once** after initial render (mount) |
| `{ a, b }` | Runs when `a` or `b` changes |

### Cleanup

Return a function from the effect to run cleanup before the next effect or on unmount:

```lua
useEffect(function()
    local timer = vim.uv.new_timer()
    timer:start(1000, 1000, function()
        print("tick")
    end)

    -- Cleanup: stop the timer
    return function()
        timer:stop()
        timer:close()
    end
end, {})
```

### Common Patterns

**Sync with props:**
```lua
useEffect(function()
    if props.value ~= nil then
        setInternal(props.value)
    end
end, { props.value })
```

**Subscribe to events:**
```lua
useEffect(function()
    local id = bus:on("data", handler)
    return function() bus:off(id) end
end, {})
```

---

## useReducer

Manages complex state logic with a reducer function. Similar to `useState` but separates state transitions into pure functions.

```lua
local useReducer = ui.hooks.useReducer

local function reducer(state, action)
    if action.type == "increment" then
        return state + 1
    elseif action.type == "decrement" then
        return state - 1
    elseif action.type == "reset" then
        return 0
    end
    return state
end

local Counter = ui.createComponent("Counter", function()
    local count, dispatch = useReducer(reducer, 0)
    return {
        Paragraph({ content = "Count: " .. count }),
        Button({ label = "+1", on_press = function() dispatch({ type = "increment" }) end }),
        Button({ label = "-1", on_press = function() dispatch({ type = "decrement" }) end }),
        Button({ label = "Reset", on_press = function() dispatch({ type = "reset" }) end }),
    }
end)
```

### Signature

```lua
---@generic T, A
---@param reducer fun(state: T, action: A): T
---@param initial T
---@return T state
---@return fun(action: A) dispatch
```

### When to Use

- State logic has multiple sub-values
- Next state depends on the previous one in complex ways
- You want to centralize state transitions for testability

---

## useConfig

Access the current framework configuration. Returns a deep copy of the config table.

```lua
local useConfig = ui.hooks.useConfig

local ThemedBox = ui.createComponent("ThemedBox", function()
    local config = useConfig()
    local border_char = config.characters.horizontal
    -- Use config values...
end)
```

### Signature

```lua
---@return ascii-ui.Config config  -- deep copy of current config
```

### Config Structure

```lua
{
    log_level = "INFO",
    characters = {
        top_left = "╭", top_right = "╮",
        bottom_left = "╰", bottom_right = "╯",
        horizontal = "─", vertical = "│",
        left_tree = "├", thumb = "●",
        whitespace = " ", right_triangule = "▸",
        down_triangule = "▾",
    },
    keymaps = {
        quit = "q",
        select = "<CR>",
    },
}
```

---

## useInterval

Runs a callback repeatedly at a fixed interval (in milliseconds). Automatically cleans up when the component unmounts or the delay changes.

```lua
local useInterval = ui.hooks.useInterval
local useState = ui.hooks.useState

local Clock = ui.createComponent("Clock", function()
    local time, setTime = useState(os.date("%H:%M:%S"))

    useInterval(function()
        setTime(os.date("%H:%M:%S"))
    end, 1000)  -- Update every second

    return { Paragraph({ content = time }) }
end)
```

### Signature

```lua
---@param callback fun()
---@param delay number|nil  -- interval in milliseconds. nil or <= 0 disables.
```

### Key Details

- Built on the `ascii-ui.utils.async` compat layer: native `vim.async`
  structured-concurrency tasks on new Neovims (nightly / 0.13+), `vim.uv`
  timers otherwise — same `close()` cancellation semantics on both
- Callback is wrapped with `vim.schedule_wrap` for thread safety
- Cleanup is automatic — no need to manually stop the timer
- If `delay` is `nil` or `<= 0`, the interval is not started

---

## useTimeout

Runs a callback once after a delay (in milliseconds). The timer restarts only when the delay value changes.

```lua
local useTimeout = ui.hooks.useTimeout
local useState = ui.hooks.useState

local DelayedMessage = ui.createComponent("DelayedMessage", function()
    local visible, setVisible = useState(false)

    useTimeout(function()
        setVisible(true)
    end, 3000)  -- Show after 3 seconds

    if not visible then
        return { Paragraph({ content = "Loading..." }) }
    end
    return { Paragraph({ content = "Welcome!" }) }
end)
```

### Signature

```lua
---@param callback fun()
---@param delay number|nil  -- delay in milliseconds. nil or < 0 disables.
```

### Key Details

- Always calls the **latest** version of the callback (via internal ref)
- Timer only restarts when `delay` changes, not on every render
- Built on the `ascii-ui.utils.async` compat layer: native `vim.async`
  task on new Neovims, `vim.uv` timer otherwise
- Automatic cleanup on unmount
- Useful for: delayed reveals, debounced actions, auto-dismiss notifications

### Pattern: Auto-dismiss Notification

```lua
local Notification = ui.createComponent("Notification", function(props)
    local visible, setVisible = useState(true)

    useTimeout(function()
        setVisible(false)
    end, 5000)  -- Dismiss after 5 seconds

    if not visible then
        return {}
    end
    return { Paragraph({ content = props.message }) }
end)
```

---

## useAsync

Runs an async function as a structured-concurrency task tied to the component
lifecycle. The task is cancelled automatically on unmount or when dependencies
change. Uses native `vim.async` when available (nightly / 0.13+), with a
`vim.uv`-backed shim on older Neovims.

```lua
local useAsync = ui.hooks.useAsync
local async = require("ascii-ui.utils.async")

local FileInfo = ui.createComponent("FileInfo", function(props)
    local size, setSize = useState(nil)

    useAsync(function()
        local err, stat = async.await(2, vim.uv.fs_stat, props.path)
        if not err and stat then
            setSize(stat.size)
        end
    end, { props.path })

    return { Paragraph({ content = size and tostring(size) or "loading..." }) }
end)
```

### Signature

```lua
---@param fn fun(...: any): any ...  -- async function (may call async.sleep / async.await)
---@param dependencies? any[]        -- re-run when any value changes
---@return ascii-ui.AsyncTask task
```

### Key Details

- Cancellation is cooperative: check `async.is_closing()` at checkpoints, or
  simply let `async.sleep` / `async.await` observe the close
- Previous task is closed before a new one starts on dependency change
- For timers prefer `useInterval` / `useTimeout`; for general async work
  (fs, jobs, LSP) prefer `useAsync`

---

## Hook Rules

Follow these rules to avoid bugs:

1. **Only call hooks at the top level** of your component function. Don't call them inside conditions, loops, or nested functions.

2. **Only call hooks from within a component** created with `createComponent`. Calling hooks outside a component context will error.

3. **Hook call order must be consistent** between renders. The framework tracks hooks by call index.

```lua
-- GOOD: hooks at top level
local MyComponent = ui.createComponent("MyComponent", function()
    local count, setCount = useState(0)
    useEffect(function() print(count) end, { count })
    return { Paragraph({ content = count }) }
end)

-- BAD: hooks inside conditionals
local MyComponent = ui.createComponent("MyComponent", function(props)
    if props.show then
        local count, setCount = useState(0)  -- Don't do this!
    end
    return {}
end)
```
