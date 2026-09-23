-- Architecture tests for the mini.test suite.
--
-- These guard the conventions every spec file must follow so the suite
-- keeps working under `MiniTest.run()` with busted emulation.

local eq = require("tests.assertions").eq

describe("arch tests", function()
	it("no spec file depends on plenary, luacov or luassert", function()
		local handle = assert(io.popen("find ./tests -type f -name '*_spec.lua'"))
		assert(handle ~= nil)

		local offenders = {}
		for file in handle:lines() do
			-- Skip this file: it names the forbidden tokens to enforce the rule.
			if not file:match("arch_spec%.lua$") then
				local f = assert(io.open(file, "r"))
				local content = f:read("*a")
				f:close()

				for _, forbidden in ipairs({ "plenary", "luacov", "luassert" }) do
					if content:find(forbidden, 1, true) then
						offenders[#offenders + 1] = file .. " references " .. forbidden
					end
				end
			end
		end
		handle:close()

		eq({}, offenders)
	end)

	it("no spec file shadows the busted-emulated `it`", function()
		local handle = assert(io.popen("find ./tests -type f -name '*_spec.lua'"))
		assert(handle ~= nil)

		local offenders = {}
		for file in handle:lines() do
			local f = assert(io.open(file, "r"))
			for line in f:lines() do
				if line:match("^%s*local%s+it%s*=") then
					offenders[#offenders + 1] = file .. " shadows global `it`"
					break
				end
			end
			f:close()
		end
		handle:close()

		eq({}, offenders)
	end)
end)
