local eq = require("tests.assertions").eq

--- @param stdout string
--- @return { status: string, headers: table, body: table }
local function response(stdout)
	-- first line is status line
	local lines = vim.split(stdout, "\n", { plain = true })

	-- parse headers
	-- the headers are separated by an empty line

	local headers = {}
	for i = 2, #lines do
		local line = lines[i]
		if line == "" then
			break
		end
		local key, value = line:match("^(.-):%s*(.*)$")
		if key and value then
			headers[key:lower()] = value
		end
	end

	-- parse body
	-- find json body between two empty lines
	local body = vim.split(stdout, "\r\n\r\n", { plain = true })[2]

	return {
		status = vim.trim(lines[1]),
		headers = headers,
		body = vim.json.decode(body),
	}
end

--- @param url string
local function fetch(url)
	local result = vim.system({ "curl", "-s", "-i", url }):wait()
	if result.code ~= 0 then
		return nil
	end
	return response(result.stdout)
end

describe("fetch", function()
	it("executes GET request", function()
		MiniTest.skip("requires network access")
		local url = "https://httpbin.org/get"
		local response_body = fetch(url)

		assert(response_body, "Response body should not be nil")

		eq(url, response_body.body.url)
		-- eq("HTTP/2 200", response_body.status) -- not reliable due to different HTTP versions
		eq("table", type(response_body.headers))
	end)
end)
