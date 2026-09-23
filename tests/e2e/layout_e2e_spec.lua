local ui = require("ascii-ui")
local Button = ui.components.Button
local Paragraph = ui.components.Paragraph
local Column = ui.layout.Column
local Row = ui.layout.Row
local useState = ui.hooks.useState
local testing_e2e = require("ascii-ui.testing.e2e")

describe("layout e2e", function()
	describe("Row", function()
		it("renders children side-by-side in actual buffer", function()
			local App = ui.createComponent("RowApp", function()
				return Row(
					Paragraph({ content = "AAA" }),
					Paragraph({ content = "BBB" }),
					Paragraph({ content = "CCC" })
				)
			end)

			local screen = testing_e2e.mount(App)

			-- Row should render children horizontally on the same line
			-- with gap of 1 space between them
			assert(screen:waitForText("AAA BBB CCC"))
		end)

		it("handles state updates in Row children", function()
			local setCount
			local App = ui.createComponent("RowStateApp", function()
				local count, _setCount = useState(0)
				setCount = _setCount
				return Row(Paragraph({ content = "count: " .. tostring(count) }), Paragraph({ content = "static" }))
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("count: 0 static"))

			setCount(5)
			assert(screen:waitForText("count: 5 static"))

			setCount(42)
			assert(screen:waitForText("count: 42 static"))
		end)

		it("handles button interaction inside Column", function()
			local App = ui.createComponent("ColumnButtonApp", function()
				local count, setCount = useState(0)
				return Column(
					Paragraph({ content = "count: " .. tostring(count) }),
					Button({
						label = "Increment",
						on_press = function()
							setCount(count + 1)
						end,
					})
				)
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("count: 0"))
			assert(screen:waitForText("Increment"))

			-- Move cursor down to the button and press enter
			screen:press("j")
			vim.schedule(function()
				local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				screen:press(enter)
			end)

			assert(screen:waitForText("count: 1"))
		end)
	end)

	describe("Column", function()
		it("renders children vertically in actual buffer", function()
			local App = ui.createComponent("ColumnApp", function()
				return Column(
					Paragraph({ content = "line1" }),
					Paragraph({ content = "line2" }),
					Paragraph({ content = "line3" })
				)
			end)

			local screen = testing_e2e.mount(App)

			-- Column should render each child on its own line
			assert(screen:waitForText("line1"))
			assert(screen:waitForText("line2"))
			assert(screen:waitForText("line3"))

			-- Verify they are on separate lines
			local lines = screen:toLines()
			local found_line1, found_line2, found_line3
			for _, line in ipairs(lines) do
				if line:find("line1", 1, true) then
					found_line1 = true
				end
				if line:find("line2", 1, true) then
					found_line2 = true
				end
				if line:find("line3", 1, true) then
					found_line3 = true
				end
			end
			assert(found_line1)
			assert(found_line2)
			assert(found_line3)
		end)

		it("handles state updates in Column children", function()
			local setMessage
			local App = ui.createComponent("ColumnStateApp", function()
				local message, _setMessage = useState("hello")
				setMessage = _setMessage
				return Column(Paragraph({ content = message }), Paragraph({ content = "footer" }))
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("hello"))
			assert(screen:waitForText("footer"))

			setMessage("world")
			assert(screen:waitForText("world"))
			assert(screen:waitForText("footer"))
		end)
	end)

	describe("nested layouts", function()
		it("renders Row inside Column with state updates", function()
			local setCount
			local App = ui.createComponent("NestedApp", function()
				local count, _setCount = useState(0)
				setCount = _setCount
				return Column(
					Paragraph({ content = "Header" }),
					Row(Paragraph({ content = "count: " .. tostring(count) }), Paragraph({ content = "end" })),
					Paragraph({ content = "Footer" })
				)
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("Header"))
			assert(screen:waitForText("count: 0 end"))
			assert(screen:waitForText("Footer"))

			setCount(10)
			assert(screen:waitForText("count: 10 end"))
		end)

		it("renders Column inside Row", function()
			local App = ui.createComponent("ColumnInRowApp", function()
				return Row(
					Column(Paragraph({ content = "A1" }), Paragraph({ content = "A2" })),
					Column(Paragraph({ content = "B1" }), Paragraph({ content = "B2" }))
				)
			end)

			local screen = testing_e2e.mount(App)

			-- Both columns should be visible
			assert(screen:waitForText("A1"))
			assert(screen:waitForText("A2"))
			assert(screen:waitForText("B1"))
			assert(screen:waitForText("B2"))
		end)
	end)

	describe("dynamic children", function()
		it("adds and removes children from Row based on state", function()
			local setItems
			local App = ui.createComponent("DynamicRowApp", function()
				local items, _setItems = useState({ "X" })
				setItems = _setItems
				local children = {}
				for _, item in ipairs(items) do
					children[#children + 1] = Paragraph({ content = item })
				end
				return Row({ children = children })
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("X"))

			setItems({ "X", "Y" })
			assert(screen:waitForText("X Y"))

			setItems({ "X", "Y", "Z" })
			assert(screen:waitForText("X Y Z"))

			setItems({ "Y", "Z" })
			assert(screen:waitForText("Y Z"))
		end)

		it("adds and removes children from Column based on state", function()
			local setItems
			local App = ui.createComponent("DynamicColumnApp", function()
				local items, _setItems = useState({ "alpha" })
				setItems = _setItems
				local children = {}
				for _, item in ipairs(items) do
					children[#children + 1] = Paragraph({ content = item })
				end
				return Column({ children = children })
			end)

			local screen = testing_e2e.mount(App)

			assert(screen:waitForText("alpha"))

			setItems({ "alpha", "beta" })
			assert(screen:waitForText("alpha"))
			assert(screen:waitForText("beta"))

			setItems({ "beta" })
			assert(screen:waitForText("beta"))
		end)
	end)
end)
