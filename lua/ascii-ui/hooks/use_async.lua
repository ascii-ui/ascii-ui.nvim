local async = require("ascii-ui.utils.async")
local fiber = require("ascii-ui.fiber")
local useEffect = require("ascii-ui.hooks.use_effect")

---
--- Runs an async function as a structured-concurrency task tied to the
--- component lifecycle. The task is cancelled automatically when the
--- component unmounts or when `dependencies` change.
---
--- On Neovim with `vim.async` (nightly / 0.13+) this uses a native task:
--- cancellation propagates cooperatively (`async.is_closing()` observes it
--- at the next checkpoint) and unhandled child errors fail the task.
--- On older Neovims a shim with the same `close` / `wait` surface is used.
---
--- ```lua
--- local useAsync = ui.hooks.useAsync
---
--- local DataView = ui.createComponent("DataView", function(props)
--- 	local data, setData = ui.hooks.useState(nil)
---
--- 	useAsync(function()
--- 		local err, stat = async.await(2, vim.uv.fs_stat, props.path)
--- 		if not err and stat then
--- 			setData(stat.size)
--- 		end
--- 	end, { props.path })
---
--- 	return { Paragraph({ content = data and tostring(data) or "loading..." }) }
--- end)
--- ```
---
--- @param fn fun(...: any): any ... async function to run (may call `async.sleep` / `async.await`)
--- @param dependencies? any[] re-run when any value changes; `{}` runs once on mount; nil runs every render
--- @param ... any extra arguments forwarded to `fn`
--- @return ascii-ui.AsyncTask|any the running task (native `vim.async.Task` when available)
local function useAsync(fn, dependencies, ...)
	local currentFiber = assert(fiber.getCurrentFiber(), "cannot call useAsync out of the component scope")
	local extra_args = { ... }

	-- Storage for the current task, keyed by hook index like useState.
	local idx = currentFiber.hookIndex
	if not currentFiber.hooks[idx] then
		currentFiber.hooks[idx] = {}
	end
	local storage = currentFiber.hooks[idx]

	useEffect(function()
		-- Cancel the previous task before starting a new one.
		if storage.task then
			pcall(function()
				storage.task:close()
			end)
			storage.task = nil
		end

		local task = async.run(fn, unpack(extra_args))
		storage.task = task

		return function()
			if storage.task then
				pcall(function()
					storage.task:close()
				end)
				storage.task = nil
			end
		end
	end, dependencies)

	currentFiber.hookIndex = idx + 1

	return storage.task
end

return useAsync
