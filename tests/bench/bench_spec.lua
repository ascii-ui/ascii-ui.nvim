-- Silence all framework logs so they don't pollute benchmark output.
require("ascii-ui.logger").set_level("QUIET")

-- Performance benchmarks for ascii-ui.nvim
--
-- Each benchmark runs a hot path N times and reports:
--   min / avg / max  in milliseconds
--
-- A hard budget (ms) is asserted so CI catches regressions.
-- Budgets are intentionally generous to survive slow CI runners
-- (ubuntu-latest, macos-latest, windows-latest, stable + nightly).

local HexaColor = require("ascii-ui.hexacolor")
local Segment = require("ascii-ui.buffer.segment")
local fiber = require("ascii-ui.fiber")
local ui = require("ascii-ui")
local useState = ui.hooks.useState

-- ─────────────────────────────────────────────────────────────
-- helpers
-- ─────────────────────────────────────────────────────────────

---Runs `fn` `n` times and returns { min, avg, max } in ms.
---@param n integer
---@param fn fun()
---@return { min: number, avg: number, max: number }
local function timeit(n, fn)
	local total = 0
	local min_ns = math.huge
	local max_ns = 0

	for _ = 1, n do
		local t0 = vim.uv.hrtime()
		fn()
		local elapsed = vim.uv.hrtime() - t0
		total = total + elapsed
		if elapsed < min_ns then
			min_ns = elapsed
		end
		if elapsed > max_ns then
			max_ns = elapsed
		end
	end

	return {
		min = min_ns / 1e6,
		avg = (total / n) / 1e6,
		max = max_ns / 1e6,
	}
end

---Pretty-print a timeit result with a label.
---@param label string
---@param n integer  number of iterations
---@param r { min: number, avg: number, max: number }
local function report(label, n, r)
	print(string.format("[bench] %-42s  n=%-5d  min=%.3fms  avg=%.3fms  max=%.3fms", label, n, r.min, r.avg, r.max))
end

local IS_WINDOWS = vim.uv.os_uname().sysname == "Windows_NT"

local function budget(ms)
	if IS_WINDOWS then
		return ms * 4
	end
	return ms
end

-- ─────────────────────────────────────────────────────────────
-- fixtures
-- ─────────────────────────────────────────────────────────────

-- A minimal leaf component (single Segment → single BufferLine).
local Leaf = ui.createComponent("BenchLeaf", function(props)
	props = props or {}
	return { Segment:new({ content = props.text or "hello" }):wrap() }
end, { text = "string" })

-- A flat list of N leaves rendered side by side via ui.map.
local function make_list_component(size)
	local items = {}
	for i = 1, size do
		items[i] = tostring(i)
	end
	return ui.createComponent("BenchList" .. size, function()
		return ui.map(items, function(item)
			return Leaf({ text = item })
		end)
	end)
end

-- A stateful component — used for rerender benchmarks.
local BenchStateful
local set_content_outside
BenchStateful = ui.createComponent("BenchStateful", function()
	local content, setContent = useState("initial")
	set_content_outside = setContent
	return { Segment:new({ content = content }):wrap() }
end)

-- ─────────────────────────────────────────────────────────────
-- benchmarks
-- ─────────────────────────────────────────────────────────────

describe("performance", function()
	-- ── 1. first render of a single leaf ──────────────────────
	it("first render — single leaf component", function()
		local N = 200
		local r = timeit(N, function()
			fiber.render(Leaf)
		end)
		report("first render / single leaf", N, r)

		-- budget: avg render of one leaf must stay under 5 ms
		assert(r.avg < budget(5), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(5)))
	end)

	-- ── 2. rerender with a state change ───────────────────────
	it("rerender — stateful component, state changes every cycle", function()
		local N = 200
		local root = fiber.render(BenchStateful)
		-- prime the hook (first rerender populates set_content_outside)
		fiber.rerender(root)

		local counter = 0
		local r = timeit(N, function()
			counter = counter + 1
			set_content_outside(tostring(counter))
			fiber.rerender(root)
		end)
		report("rerender / state change every cycle", N, r)

		-- budget: avg rerender must stay under 5 ms
		assert(r.avg < budget(5), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(5)))
	end)

	-- ── 3. rerender with NO state change (NONE path) ──────────
	it("rerender — no state change (NONE fast-path)", function()
		local N = 200
		local root = fiber.render(Leaf)
		fiber.rerender(root)

		local r = timeit(N, function()
			fiber.rerender(root)
		end)
		report("rerender / no state change (NONE)", N, r)

		-- budget: the NONE fast-path should be very cheap
		assert(r.avg < budget(2), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(2)))
	end)

	-- ── 4. get_buffer — tree walk ──────────────────────────────
	it("get_buffer — tree walk after render", function()
		local N = 200
		local List20 = make_list_component(20)
		local root = fiber.render(List20)

		local r = timeit(N, function()
			root:get_buffer()
		end)
		report("get_buffer / 20-leaf tree", N, r)

		-- budget: collecting lines from a 20-node tree must stay under 5 ms
		assert(r.avg < budget(5), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(5)))
	end)

	-- ── 5. render — wider flat tree (stress) ──────────────────
	it("first render — flat list of 50 leaves", function()
		local N = 50
		local List50 = make_list_component(50)

		local r = timeit(N, function()
			fiber.render(List50)
		end)
		report("first render / 50-leaf list", N, r)

		-- budget: 50 leaves must render in under 100 ms on average
		-- (component creation + memoize key gen is expensive; this is a stress test)
		assert(r.avg < budget(100), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(100)))
	end)

	-- ── 6. reconcileChildren — repeated diffing ────────────────
	it("reconcileChildren — repeated child diffing", function()
		local N = 500

		-- Build real component fiber nodes (with closures) so is_same works correctly.
		local children = {}
		for i = 1, 10 do
			local comp = ui.createComponent("BenchChild" .. i, function()
				return { Segment:new({ content = "item" .. i }):wrap() }
			end)
			children[i] = comp()
		end

		-- Render so child nodes are fully initialised (have output / child links).
		local parent = ui.createComponent("BenchParent10", function()
			return children
		end)
		local root = fiber.render(parent)

		local r = timeit(N, function()
			fiber.reconcileChildren(root, children)
		end)
		report("reconcileChildren / 10 children", N, r)

		-- budget: diffing 10 children must stay under 5 ms on average
		assert(r.avg < budget(5), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(5)))
	end)
end)

-- ─────────────────────────────────────────────────────────────
-- stress tests
-- ─────────────────────────────────────────────────────────────

describe("stress", function()
	-- ── S1. 100 colored segments ───────────────────────────────
	-- Each leaf carries a unique hex color, stressing HexaColor
	-- highlight-group registration and colored-segment rendering.
	it("first render — 100 uniquely colored segments", function()
		local N = 20
		-- Pre-build a palette of 100 distinct hex colors.
		local palette = {}
		for i = 0, 99 do
			palette[i + 1] = string.format("#%02x%02x%02x", (i * 13) % 256, (i * 37) % 256, (i * 71) % 256)
		end

		local ColorList = ui.createComponent("StressColorList", function()
			local segs = {}
			for i, hex in ipairs(palette) do
				local color = HexaColor.new(hex)
				segs[i] = Segment:new({ content = "■", highlight = color:get_highlight() }):wrap()
			end
			return segs
		end)

		local r = timeit(N, function()
			fiber.render(ColorList)
		end)
		report("stress / 100 colored segments", N, r)

		-- budget: 100 colored leaves must render in under 200 ms on average
		assert(r.avg < budget(200), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(200)))
	end)

	-- ── S2. Clock-like component — rapid time-string rerenders ──
	-- Simulates a clock ticking: a stateful component whose content
	-- is replaced on every cycle (always a different string).
	it("rerender — clock-like rapid state updates (200 ticks)", function()
		local N = 200
		local set_time
		local Clock = ui.createComponent("StressClock", function()
			local time, setTime = useState("00:00:00")
			set_time = setTime
			return { Segment:new({ content = tostring(time) }):wrap() }
		end)

		local root = fiber.render(Clock)
		-- prime the upvalue
		fiber.rerender(root)

		local tick = 0
		local r = timeit(N, function()
			tick = tick + 1
			local h = math.floor(tick / 3600) % 24
			local m = math.floor(tick / 60) % 60
			local s = tick % 60
			set_time(string.format("%02d:%02d:%02d", h, m, s))
			fiber.rerender(root)
		end)
		report("stress / clock rerender (200 ticks)", N, r)

		-- budget: each tick rerender must stay under 5 ms on average
		assert(r.avg < budget(5), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(5)))
	end)

	-- ── S3. Many independent stateful components ───────────────
	-- 20 stateful components rendered in a flat list; all setters
	-- are fired before each rerender, maximising reconciler churn.
	it("rerender — 20 concurrent stateful components", function()
		local N = 100
		local setters = {}

		local children = {}
		for i = 1, 20 do
			local comp = ui.createComponent("StressStateful" .. i, function()
				local val, setVal = useState("v0")
				setters[i] = setVal
				return { Segment:new({ content = tostring(val) }):wrap() }
			end)
			children[i] = comp()
		end

		local Parent = ui.createComponent("StressParent20", function()
			return children
		end)
		local root = fiber.render(Parent)
		-- prime all setters
		fiber.rerender(root)

		local cycle = 0
		local r = timeit(N, function()
			cycle = cycle + 1
			for _, setter in ipairs(setters) do
				setter("v" .. cycle)
			end
			fiber.rerender(root)
		end)
		report("stress / 20 stateful components rerender", N, r)

		-- budget: 20 concurrent stateful rerenders must stay under 150 ms on average
		assert(r.avg < budget(150), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(150)))
	end)

	-- ── S4. Deep nested component tree ─────────────────────────
	-- A chain of 10 wrapper components (each renders its child),
	-- stressing recursive fiber.render and get_buffer tree walking.
	it("first render + get_buffer — 10-level deep nested tree", function()
		local N = 50
		-- Build inside-out: innermost is a plain leaf.
		local innermost = ui.createComponent("StressDeep_0", function()
			return { Segment:new({ content = "deep" }):wrap() }
		end)

		local current = innermost
		for depth = 1, 9 do
			local child = current
			current = ui.createComponent("StressDeep_" .. depth, function()
				return { child() }
			end)
		end
		local DeepTree = current

		local r = timeit(N, function()
			local root = fiber.render(DeepTree)
			root:get_buffer()
		end)
		report("stress / 10-level deep tree render+get_buffer", N, r)

		-- budget: a 10-level deep tree must render + collect in under 100 ms
		assert(r.avg < budget(100), string.format("avg %.3fms exceeds %dms budget", r.avg, budget(100)))
	end)
end)
