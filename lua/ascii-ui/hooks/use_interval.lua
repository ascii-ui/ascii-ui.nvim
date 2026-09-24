local async = require("ascii-ui.utils.async")
local useEffect = require("ascii-ui.hooks.use_effect")

---
--- Executes a callback function at specified intervals.
---
--- @param callback function The function to be executed at each interval.
--- @param delay number|nil The interval delay in milliseconds. If nil, the interval is not set.
local function useInterval(callback, delay)
	local timer_ref = {}

	useEffect(function()
		if delay == nil or delay <= 0 then
			return
		end

		-- Structured concurrency via the async compat layer: native
		-- `vim.async` task when available, `vim.uv` timer otherwise.
		local handle = async.every(delay, callback)
		timer_ref.current = handle

		return function()
			if timer_ref.current then
				timer_ref.current:close()
				timer_ref.current = nil
			end
		end
	end, { delay })
end

return useInterval
