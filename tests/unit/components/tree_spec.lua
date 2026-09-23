local eq = require("tests.assertions").eq

local Segment = require("ascii-ui.buffer.segment")
local Tree = require("ascii-ui.components.tree")
local fiber = require("ascii-ui.fiber")
local ui = require("ascii-ui")

describe("Tree Component", function()
	it("renders just top node", function()
		local App = ui.createComponent("App", function()
			return Tree({ tree = { text = "dummy_treenode" } })
		end, {})
		local buffer = fiber.render(App):get_buffer()

		eq([[dummy_treenode]], buffer:to_string())
	end)

	it("renders just top node and its children", function()
		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "node-1",
			children = {
				{ text = "node-1-1" },
				{ text = "node-1-2" },
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq(
			vim.trim([[node-1
 ├─ node-1-1
 ╰─ node-1-2]]),
			fiber.render(App):get_buffer():to_string()
		)
	end)

	it("renders level 3 children", function()
		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "node-1",
			children = {
				{ text = "node-1-1", children = { { text = "node-1-1-1" } } },
				{ text = "node-1-2" },
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq({
			--
			"node-1",
			" ╰╮─ ▾ node-1-1",
			" │╰─ node-1-1-1",
			" ╰─ node-1-2",
		}, fiber.render(App):get_buffer():to_lines())
	end)

	it("renders last level one node with space before its children", function()
		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "node-1",
			children = {
				{ text = "node-1-1" },
				{ text = "node-1-2" },
				{ text = "node-1-3", children = { { text = "node-1-3-1", children = { { text = "node-1-3-1-1" } } } } },
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq({
			"node-1",
			" ├─ node-1-1",
			" ├─ node-1-2",
			" ╰╮─ ▾ node-1-3",
			"  ╰╮─ ▾ node-1-3-1",
			"   ╰─ node-1-3-1-1",
		}, fiber.render(App):get_buffer():to_lines())
	end)

	it("renders nodes that are not expanded", function()
		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "node-1",
			children = {
				{ text = "node-1-1" },
				{ text = "node-1-2", expanded = false, children = { { text = "node-1-2-1" } } },
				{
					text = "node-1-3",
					expanded = false,
					children = { { text = "node-1-3-1", children = { { text = "node-1-3-1-1" } } } },
				},
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})
		local result = fiber.render(App):get_buffer():to_string()

		eq(
			[[node-1
 ├─ node-1-1
 ├─ ▸ node-1-2
 ╰─ ▸ node-1-3]],
			result
		)
	end)

	it("renders component children", function()
		local CustomComponent = ui.createComponent("CustomComponent", function(props)
			return { Segment:new({ content = "[CUSTOM: " .. props.label .. "]" }):wrap() }
		end, { label = "string" })

		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "root",
			children = {
				CustomComponent({ label = "item1" }),
				CustomComponent({ label = "item2" }),
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq({
			"root",
			" ├─ [CUSTOM: item1]",
			" ╰─ [CUSTOM: item2]",
		}, fiber.render(App):get_buffer():to_lines())
	end)

	it("renders mixed text and component children", function()
		local CustomComponent = ui.createComponent("CustomComponent", function(props)
			return { Segment:new({ content = "[COMP:" .. props.text .. "]" }):wrap() }
		end, { text = "string" })

		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "root",
			children = {
				{ text = "text-node" },
				CustomComponent({ text = "comp-node" }),
				{ text = "another-text" },
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq({
			"root",
			" ├─ text-node",
			" ├─ [COMP:comp-node]",
			" ╰─ another-text",
		}, fiber.render(App):get_buffer():to_lines())
	end)

	it("renders nested component children", function()
		local CustomComponent = ui.createComponent("CustomComponent", function(props)
			return { Segment:new({ content = "nested-" .. props.value }):wrap() }
		end, { value = "string" })

		--- @type ascii-ui.TreeComponentProps.TreeNode
		local tree = {
			text = "level-0",
			children = {
				{
					text = "level-1",
					children = {
						CustomComponent({ value = "deep" }),
					},
				},
			},
		}
		local App = ui.createComponent("App", function()
			return Tree({ tree = tree })
		end, {})

		eq({
			"level-0",
			" ╰╮─ ▾ level-1",
			"  ╰─ nested-deep",
		}, fiber.render(App):get_buffer():to_lines())
	end)
end)
