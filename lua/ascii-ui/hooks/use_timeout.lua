local async = require("ascii-ui.utils.async")
local fiber = require("ascii-ui.fiber")
local useEffect = require("ascii-ui.hooks.use_effect")

---
--- Executes a callback function after a specified delay.
--- The callback always has access to the latest closure values via a ref.
--- The timer only restarts when the delay value changes, not on every render.
---
--- @param callback function The function to be executed after the delay.
--- @param delay number|nil The delay in milliseconds. If nil or negative, the timeout is not set.
local function useTimeout(callback, delay)
	local currentFiber = assert(fiber.getCurrentFiber(), "cannot call useTimeout out of the component scope")

	-- Use hookIndex for per-instance storage (like useState)
	local idx = currentFiber.hookIndex

	-- Initialize storage for this timeout instance
	if not currentFiber.hooks[idx] then
		currentFiber.hooks[idx] = {
			callbackRef = {},
		}
	end

	local storage = currentFiber.hooks[idx]
	-- Always update the callback ref so it has the latest closure
	storage.callbackRef.current = callback

	-- Use {delay} as dependencies so timer only restarts when delay changes
	useEffect(function()
		if delay == nil or delay < 0 then
			return -- Do nothing if delay is nil or negative
		end

		-- Structured concurrency via the async compat layer: native
		-- `vim.async` task when available, `vim.uv` timer otherwise.
		-- The handle exposes `close()` for effect cleanup / unmount.
		local handle = async.after(delay, function()
			-- Call the latest callback via the ref
			if storage.callbackRef and storage.callbackRef.current then
				storage.callbackRef.current()
			end
		end)

		return function()
			handle:close()
		end
	end, { delay }) -- Only restart when delay changes

	currentFiber.hookIndex = idx + 1
end

return useTimeout
