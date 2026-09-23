local MINIMAL_CONFIG = "scripts/minimal_init.lua"

local function run(filename)
	local handle = assert(io.popen(("nvim -u %s -l %s "):format(MINIMAL_CONFIG, filename)))

	local output = vim
		.iter(handle:lines())
		--
		:totable()

	local success = not vim.iter(output):any(function(line)
		return not not string.find(line, "ERROR")
	end)

	handle:close()

	return { filename = filename, success = success, output = output }
end

describe("examples", function()
	it("load without errors", function()
		local handle = assert(io.popen("find ./examples -type f -name '*.lua'"))

		for file in handle:lines() do
			local f = assert(io.open(file, "r"))

			local result = run(file)
			f:close()

			if not result.success then
				handle:close()
				error("Error in file: " .. result.filename)
			end
		end
		handle:close()
	end)
end)
