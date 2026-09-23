local eq = require("tests.assertions").eq
local Segment = require("ascii-ui.buffer.segment")
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

describe("ui.createComponent", function()
	local DummyComponent = ui.createComponent("DummyComponent", function(props)
		props = props or {}

		return { Segment:new({ content = props.content, interactions = { on_select = props.on_select } }):wrap() }
	end, { content = "string", on_select = "function" })

	it("creates a component with diferent overloads", function()
		local expected_output = { "t-shirt" }

		-- Anonymous component without name
		do
			local AnonymousComponent = ui.createComponent(function()
				return {
					DummyComponent({ content = "t-shirt" }),
				}
			end)
			eq(expected_output, testing.render(AnonymousComponent):toLines())
		end

		-- Anonymous component with non typed props
		do
			local AnonymousComponent = ui.createComponent(function(props)
				return {
					DummyComponent({ content = props.content or "" }),
				}
			end)

			eq(
				expected_output,
				testing
					.render(function()
						return AnonymousComponent({ content = "t-shirt" })
					end)
					:toLines()
			)
		end

		-- Named component
		do
			local NamedComponent = ui.createComponent("NamedComponent", function()
				return {
					DummyComponent({ content = "t-shirt" }),
				}
			end)
			eq(expected_output, testing.render(NamedComponent):toLines())
		end

		-- Component with nested nodes
		do
			local NamedComponent = ui.createComponent("NamedComponent", function()
				return { {
					DummyComponent({ content = "t-shirt" }),
				} }
			end)
			eq(expected_output, testing.render(NamedComponent):toLines())
		end

		-- Component with empty places
		do
			local App2 = ui.createComponent("App2", function()
				return {
					nil,
					DummyComponent({ content = "t-shirt" }),
				}
			end)

			eq(expected_output, testing.render(App2):toLines())
		end

		-- Component that is used as a child of another component
		do
			local ParentComponent = ui.createComponent("ParentComponent", function()
				return {
					DummyComponent({ content = "t-shirt" }),
				}
			end)

			local ChildComponent = ui.createComponent("ChildComponent", function()
				return {
					ParentComponent(),
				}
			end)

			eq(expected_output, testing.render(ChildComponent):toLines())
		end
	end)

	it("validates props on definition call", function()
		local ok, err = pcall(function()
			DummyComponent({ content = 2 })
		end)
		assert(not ok)
		assert(err:find("DummyComponent"), "error should mention the component name")
		assert(err:find("content"), "error should mention the invalid prop key")
		assert(err:find("string"), "error should mention the expected type")
		assert(err:find("number"), "error should mention the actual type")
	end)

	it("prop validation error includes component name", function()
		local Typed = ui.createComponent("Typed", function(props)
			return { require("ascii-ui.buffer.segment"):new({ content = props.label }):wrap() }
		end, { label = "string" })

		local ok, err = pcall(function()
			Typed({ label = 42 })
		end)

		assert(not ok)
		assert(err:find("Typed"), "error should mention component name 'Typed'")
		assert(err:find("label"), "error should mention the invalid prop 'label'")
		assert(err:find("string"), "error should mention expected type 'string'")
		assert(err:find("number"), "error should mention actual type 'number'")
	end)
end)
