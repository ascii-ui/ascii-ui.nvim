local async = require("ascii-ui.utils.async")

local eq = require("tests.assertions").eq

describe("async compat", function()
	it("reports native availability as a boolean", function()
		eq(type(async.has_native()), "boolean")
		eq(async.has_native(), vim.async ~= nil)
	end)

	it("after() fires once after the delay", function()
		local count = 0
		async.after(30, function()
			count = count + 1
		end)
		vim.wait(500, function()
			return count == 1
		end)
		eq(1, count)
	end)

	it("after() with nil or negative delay returns a closed handle", function()
		local nil_handle = async.after(nil, function() end)
		eq(true, nil_handle:is_closing())
		local neg_handle = async.after(-1, function() end)
		eq(true, neg_handle:is_closing())
	end)

	it("after() handle can cancel before firing", function()
		local count = 0
		local handle = async.after(50, function()
			count = count + 1
		end)
		handle:close()
		vim.wait(200, function()
			return false
		end)
		eq(0, count)
		eq(true, handle:is_closing())
	end)

	it("every() fires repeatedly until closed", function()
		local count = 0
		local handle = async.every(30, function()
			count = count + 1
		end)
		vim.wait(500, function()
			return count >= 2
		end)
		assert(count >= 2, "expected at least 2 ticks, got " .. count)
		handle:close()
		local frozen = count
		vim.wait(150, function()
			return false
		end)
		eq(frozen, count)
	end)

	it("every() with nil delay returns a closed handle", function()
		local handle = async.every(nil, function() end)
		eq(true, handle:is_closing())
	end)

	it("defer() fires after the delay", function()
		local fired = false
		async.defer(function()
			fired = true
		end, 30)
		vim.wait(500, function()
			return fired
		end)
		eq(true, fired)
	end)

	it("debounce() collapses rapid calls into one", function()
		local count = 0
		local last_arg = nil
		local debounced = async.debounce(function(arg)
			count = count + 1
			last_arg = arg
		end, 60)
		debounced("first")
		debounced("second")
		debounced("third")
		vim.wait(500, function()
			return count == 1
		end)
		eq(1, count)
		eq("third", last_arg)
	end)

	it("debounce().cancel() drops the pending call", function()
		local count = 0
		local debounced = async.debounce(function()
			count = count + 1
		end, 60)
		debounced()
		debounced.cancel()
		vim.wait(200, function()
			return false
		end)
		eq(0, count)
	end)

	it("run() resolves and wait() returns the value", function()
		local task = async.run(function()
			return "done"
		end)
		local result = task:wait(1000)
		eq("done", result)
		eq(true, task:completed())
	end)

	it("run() propagates errors through wait()", function()
		local task = async.run(function()
			error("boom", 0)
		end)
		local ok = pcall(function()
			task:wait(1000)
		end)
		eq(false, ok)
	end)

	it("run() supports on_complete observation", function()
		local seen_err = "unset"
		local seen_value = "unset"
		local task = async.run(function()
			return 42
		end)
		task:on_complete(function(err, value)
			seen_err = err
			seen_value = value
		end)
		vim.wait(1000, function()
			return task:completed()
		end)
		eq(nil, seen_err)
		eq(42, seen_value)
	end)

	it("timeout() raises on deadline and closes the task", function()
		local task = async.run(function()
			async.sleep(5000)
			return "late"
		end)
		local ok, err = pcall(function()
			async.timeout(50, task)
		end)
		eq(false, ok)
		assert(err ~= nil, "expected a timeout error")
	end)
end)
