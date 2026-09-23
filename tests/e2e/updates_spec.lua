local ui = require("ascii-ui")
local Paragraph = ui.components.Paragraph
local Button = ui.components.Button
local useState = ui.hooks.useState
local useEffect = ui.hooks.useEffect

local logger = require("ascii-ui.logger")
local metrics = require("ascii-ui.utils.metrics")

local function feed(keys)
	vim.api.nvim_feedkeys(keys, "mtx", true)
end

---@param bufnr integer
---@param pattern string
---@return boolean
local function buffer_contains(bufnr, pattern)
	return vim.wait(1000, function()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local content_str = vim.iter(lines):join("\n")

		print(content_str)
		print("")
		return string.find(content_str, pattern, 1, true) ~= nil
	end)
end

describe("UI updates", function()
	local log = {}

	local App = ui.createComponent("App", function()
		local count, setCount = useState(0)
		local message, setMessage = useState("hola")

		useEffect(function()
			metrics.inc("App.useEffect.calls")

			-- NOTE: This is just to avoid infinite loop in the test
			log[#log + 1] = ("useEffect called with count: %d"):format(count)
			assert(#log < 10, "useEffect should not be called more than twice")
			if count > 0 then
				setMessage(("Button has been pressed %d times"):format(count))
			end
		end, { count })

		return {
			Paragraph({ content = message }),
			Button({
				label = "Press me",
				on_press = function()
					setCount(count + 1)
				end,
			}),
		}
	end)

	it("does run just once", function()
		local bufnr = ui.mount(App)

		feed("j") -- move cursor down to the button
		vim.schedule(function()
			local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
			feed(enter) -- simulate pressing Enter on the button
		end)

		logger.debug("Metrics: " .. vim.inspect(metrics.all()))
		assert(buffer_contains(bufnr, "Button has been pressed 1 times"))
	end)
end)
