--- Structured-concurrency async utilities with `vim.async` support and fallback.
---
--- `vim.async` (Neovim nightly / 0.13+, see `:h vim.async`, PR #34473,
--- derived from lewis6991/async.nvim) provides cooperative tasks, cancellation,
--- timeouts, and semaphores. Older Neovims (stable, 0.11) do not have it, so
--- every helper here works on both runtimes:
---
--- - when `vim.async` exists, timers and tasks use native structured
---   concurrency (`run` / `sleep` / `Task:close`);
--- - otherwise a `vim.uv` timer fallback with the same handle shape is used.
---
--- Use this module instead of calling `vim.uv.new_timer`,
--- `vim.defer_fn`, or `vim.schedule_wrap` directly so behavior stays
--- consistent across Neovim versions.
---
--- ```lua
--- local async = require("ascii-ui.utils.async")
---
--- -- one-shot, cancellable
--- local handle = async.after(300, function()
--- 	print("fired")
--- end)
--- handle:close() -- cancel before it fires
---
--- -- repeating
--- local ticker = async.every(1000, function()
--- 	print("tick")
--- end)
--- ticker:close()
---
--- -- structured task (native Task on new Nvim, shim otherwise)
--- local task = async.run(function()
--- 	async.sleep(100)
--- 	return "done"
--- end)
--- print(task:wait(1000))
--- ```
---
--- @class ascii-ui.AsyncHandle
--- @field close fun(self?: ascii-ui.AsyncHandle, callback?: fun()) Cancel the timer/task.
--- @field is_closing fun(self?: ascii-ui.AsyncHandle): boolean True after `close()` was called.
---
--- @class ascii-ui.AsyncTask : ascii-ui.AsyncHandle
--- @field completed fun(self: ascii-ui.AsyncTask): boolean
--- @field status fun(self: ascii-ui.AsyncTask): string
--- @field wait fun(self: ascii-ui.AsyncTask, timeout?: integer): any ...
--- @field pwait fun(self: ascii-ui.AsyncTask, timeout?: integer): boolean, any ...
--- @field detach fun(self: ascii-ui.AsyncTask): ascii-ui.AsyncTask
--- @field on_complete fun(self: ascii-ui.AsyncTask, callback: fun(err?: any, ...: any)): fun()
--- @field raise_on_error fun(self: ascii-ui.AsyncTask): ascii-ui.AsyncTask

local M = {}

--- Returns true when the native `vim.async` API is available.
--- @return boolean
function M.has_native()
	return vim.async ~= nil
end

--- Schedules `fn` on the main loop (thin wrapper over `vim.schedule`).
--- Kept here so callers only require one async module.
--- @param fn fun()
function M.schedule(fn)
	vim.schedule(fn)
end

--- Suspends the current task for `ms` milliseconds without blocking.
--- Must be called inside `M.run` (or `vim.async.run`).
--- Fallback (no native `vim.async`): blocking `vim.wait`, honoring close.
--- @param ms integer milliseconds to sleep
function M.sleep(ms)
	local native = vim.async
	if native then
		native.sleep(ms)
		return
	end
	vim.wait(ms, function()
		return false
	end)
end

--- Returns true if the current async task has been asked to close.
--- Outside a task, always returns false.
--- @return boolean
function M.is_closing()
	local native = vim.async
	if native and native.is_closing then
		local ok, closing = pcall(native.is_closing)
		if ok then
			return closing == true
		end
	end
	return false
end

-- ─── native task helpers ─────────────────────────────────────────────────────

--- Creates a cancellable one-shot timer from a native `vim.async` task.
--- @param delay integer ms
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
local function native_after(delay, fn)
	local closed = false
	local task = vim.async.run(function()
		vim.async.sleep(delay)
		if closed or vim.async.is_closing() then
			return
		end
		vim.schedule(fn)
	end)
	return {
		close = function(_, callback)
			closed = true
			task:close(callback)
		end,
		is_closing = function()
			return closed or task:completed()
		end,
		_task = task,
	}
end

--- Creates a cancellable repeating timer from a native `vim.async` task.
--- @param delay integer ms
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
local function native_every(delay, fn)
	local closed = false
	local task = vim.async.run(function()
		while not closed and not vim.async.is_closing() do
			vim.async.sleep(delay)
			if closed or vim.async.is_closing() then
				break
			end
			vim.schedule(fn)
		end
	end)
	return {
		close = function(_, callback)
			closed = true
			task:close(callback)
		end,
		is_closing = function()
			return closed or task:completed()
		end,
		_task = task,
	}
end

-- ─── uv-timer fallback ───────────────────────────────────────────────────────

--- Wraps a `vim.uv` timer handle in the shared `AsyncHandle` shape.
--- @param timer uv.uv_timer_t|nil
--- @return ascii-ui.AsyncHandle
local function wrap_uv_timer(timer)
	local closed = timer == nil
	local handle = {}
	handle.closed = closed
	handle._timer = timer
	function handle.close(_, callback)
		if closed then
			if callback then
				vim.schedule(callback)
			end
			return
		end
		closed = true
		handle.closed = true
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		if callback then
			vim.schedule(callback)
		end
	end
	function handle.is_closing()
		return closed
	end
	return handle
end

--- Fallback one-shot timer via `vim.uv`.
--- @param delay integer ms
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
local function uv_after(delay, fn)
	if delay == nil or delay < 0 then
		return wrap_uv_timer(nil)
	end
	local timer = assert(vim.uv.new_timer())
	local handle = wrap_uv_timer(timer)
	timer:start(
		delay,
		0,
		vim.schedule_wrap(function()
			if handle:is_closing() then
				return
			end
			handle.closed = true
			timer:stop()
			timer:close()
			fn()
		end)
	)
	return handle
end

--- Fallback repeating timer via `vim.uv`.
--- @param delay integer ms
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
local function uv_every(delay, fn)
	if delay == nil or delay <= 0 then
		return wrap_uv_timer(nil)
	end
	local timer = assert(vim.uv.new_timer())
	local handle = wrap_uv_timer(timer)
	timer:start(
		delay,
		delay,
		vim.schedule_wrap(function()
			if handle:is_closing() then
				return
			end
			fn()
		end)
	)
	return handle
end

--- Runs `fn` once after `delay` ms. Returns a cancellable handle.
--- On native runtimes this is a `vim.async` task (cooperative cancel);
--- otherwise a `vim.uv` timer. Either way `handle:close()` cancels.
--- @param delay integer ms; nil/negative returns an already-closed handle
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
function M.after(delay, fn)
	if delay == nil or delay < 0 then
		return wrap_uv_timer(nil)
	end
	if M.has_native() then
		local ok, handle = pcall(native_after, delay, fn)
		if ok then
			return handle
		end
	end
	return uv_after(delay, fn)
end

--- Runs `fn` every `delay` ms until the returned handle is closed.
--- @param delay integer ms; nil/non-positive returns an already-closed handle
--- @param fn fun()
--- @return ascii-ui.AsyncHandle
function M.every(delay, fn)
	if delay == nil or delay <= 0 then
		return wrap_uv_timer(nil)
	end
	if M.has_native() then
		local ok, handle = pcall(native_every, delay, fn)
		if ok then
			return handle
		end
	end
	return uv_every(delay, fn)
end

--- Alias for `M.after`, replacing direct `vim.defer_fn` usage.
--- @param fn fun()
--- @param delay integer ms
--- @return ascii-ui.AsyncHandle
function M.defer(fn, delay)
	return M.after(delay, fn)
end

--- Returns a debounced version of `fn`: rapid calls collapse into one
--- invocation `delay` ms after the last call. The pending call can be
--- cancelled via the `.cancel()` method on the debounced function.
--- @param fn fun(...: any)
--- @param delay integer ms
--- @return fun(...: any) debounced
function M.debounce(fn, delay)
	local pending = nil
	local function cancel_pending()
		if pending then
			pending:close()
			pending = nil
		end
	end
	local debounced = setmetatable({
		cancel = cancel_pending,
	}, {
		__call = function(_, ...)
			local args = { ... }
			cancel_pending()
			pending = M.after(delay, function()
				pending = nil
				fn(unpack(args))
			end)
		end,
	})
	return debounced
end

-- ─── task shim (fallback when vim.async is missing) ──────────────────────────

--- Builds a minimal Task-compatible shim around scheduled execution.
--- Supports `wait` / `pwait` (via `vim.wait` polling), `close`,
--- `detach`, `on_complete`, `completed`, and `status`.
--- @param fn fun(...: any): any ...
--- @param ... any arguments forwarded to `fn`
--- @return ascii-ui.AsyncTask
local function shim_run(fn, ...)
	local args = { ... }
	local task = {
		_completed = false,
		_ok = false,
		_results = {},
		_close_requested = false,
		_callbacks = {},
	}
	function task:completed()
		return self._completed
	end
	function task:status()
		return self._completed and "completed" or "running"
	end
	function task:is_closing()
		return self._close_requested == true
	end
	function task:close(callback)
		self._close_requested = true
		if callback then
			self:on_complete(function()
				callback()
			end)
		end
	end
	function task:detach()
		return self
	end
	function task:raise_on_error()
		return self
	end
	function task:on_complete(callback)
		if self._completed then
			vim.schedule(function()
				if self._ok then
					callback(nil, unpack(self._results))
				else
					callback(self._results[1])
				end
			end)
			return function() end
		end
		table.insert(self._callbacks, callback)
		return function()
			for idx, cb in ipairs(self._callbacks) do
				if cb == callback then
					table.remove(self._callbacks, idx)
					break
				end
			end
		end
	end
	local function finish(ok, ...)
		if task._completed then
			return
		end
		task._completed = true
		task._ok = ok
		task._results = { ... }
		local callbacks = task._callbacks
		task._callbacks = {}
		for _, cb in ipairs(callbacks) do
			if ok then
				cb(nil, ...)
			else
				cb(...)
			end
		end
	end
	function task:wait(timeout)
		local ok = vim.wait(timeout or 5000, function()
			return self._completed
		end)
		if not ok then
			error("timeout", 2)
		end
		if not self._ok then
			error(self._results[1], 2)
		end
		return unpack(self._results)
	end
	function task:pwait(timeout)
		local results = { pcall(self.wait, self, timeout) }
		local ok = table.remove(results, 1)
		if ok then
			return true, unpack(results)
		end
		return false, unpack(results)
	end
	vim.schedule(function()
		if task._close_requested then
			finish(false, "closed")
			return
		end
		local results = { pcall(fn, unpack(args)) }
		local ok = table.remove(results, 1)
		finish(ok, unpack(results))
	end)
	return task
end

--- Creates a task from an async function.
--- Native when `vim.async` exists (structured concurrency: children attach,
--- cancel propagates, errors bubble to the parent); otherwise a shim with the
--- same `wait` / `close` / `on_complete` surface.
---
--- Accepts both `run(fn, ...)` and `run(name, fn, ...)` signatures.
--- @param fn_or_name fun(...: any): any ... | string
--- @param ... any
--- @return ascii-ui.AsyncTask|any native Task when available
function M.run(fn_or_name, ...)
	if M.has_native() then
		return vim.async.run(fn_or_name, ...)
	end
	local fn = fn_or_name
	local args = { ... }
	if type(fn_or_name) == "string" then
		fn = args[1]
		table.remove(args, 1)
	end
	assert(type(fn) == "function", "async.run expects a function")
	return shim_run(fn, unpack(args))
end

--- Awaits a task or callback-style function inside `M.run`.
--- Native: `vim.async.await`. Fallback: polls task completion via `vim.wait`,
--- or invokes callback-style functions synchronously.
--- @param ... any same forms as `vim.async.await`
--- @return any ...
function M.await(...)
	if M.has_native() then
		return vim.async.await(...)
	end
	local first = select(1, ...)
	if type(first) == "table" and type(first.wait) == "function" then
		return first:wait()
	end
	if type(first) == "function" then
		local done = false
		local results = {}
		first(function(...)
			results = { ... }
			done = true
		end)
		vim.wait(5000, function()
			return done
		end)
		return unpack(results)
	end
	if type(first) == "number" then
		local argc = first
		local func = select(2, ...)
		assert(type(func) == "function", "async.await expects a function at position 2")
		local call_args = {}
		for idx = 3, 2 + argc - 1 do
			call_args[#call_args + 1] = select(idx, ...)
		end
		local done = false
		local results = {}
		call_args[argc] = function(...)
			results = { ... }
			done = true
		end
		func(unpack(call_args))
		vim.wait(5000, function()
			return done
		end)
		return unpack(results)
	end
	error("async.await fallback: unsupported awaitable", 2)
end

--- Protected await; returns `ok, ...` instead of raising.
--- @param ... any same forms as `M.await`
--- @return boolean ok
function M.pawait(...)
	if M.has_native() then
		return vim.async.pawait(...)
	end
	local results = { pcall(M.await, ...) }
	return unpack(results)
end

--- Wraps a callback-style function into an async function.
--- Native: `vim.async.wrap`. Fallback: synchronous wrapper.
--- @param argc integer callback position (1-based)
--- @param func fun(...: any)
--- @return fun(...: any)
function M.wrap(argc, func)
	if M.has_native() then
		return vim.async.wrap(argc, func)
	end
	return function(...)
		local call_args = { ... }
		local done = false
		local results = {}
		call_args[argc] = function(...)
			results = { ... }
			done = true
		end
		func(unpack(call_args))
		vim.wait(5000, function()
			return done
		end)
		return unpack(results)
	end
end

--- Awaits a task with a deadline; closes the task and raises `"timeout"`
--- when the deadline wins. Native uses `vim.async.timeout`, fallback polls.
--- @param duration integer ms
--- @param task ascii-ui.AsyncTask|any
--- @return any ...
function M.timeout(duration, task)
	if M.has_native() then
		return vim.async.timeout(duration, task)
	end
	local ok = vim.wait(duration, function()
		return task:completed()
	end)
	if not ok then
		pcall(function()
			task:close()
		end)
		error("timeout", 2)
	end
	return task:wait(0)
end

return M
