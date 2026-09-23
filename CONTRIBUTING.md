# Contributing to ascii-ui.nvim

Thanks for taking the time to contribute. Whether you are a human Neovim plugin author or an AI agent helping out, this guide will get you productive quickly.

## Development setup

1. Clone the repository:

   ```bash
   git clone https://github.com/ascii-ui/ascii-ui.nvim.git
   cd ascii-ui.nvim
   ```

2. Install the tooling:

   - [lux](https://github.com/lux-cli/lux) — Lua package manager
   - [stylua](https://github.com/JohnnyMorganz/StyLua) — Lua formatter
   - [luacheck](https://github.com/lunarmodules/luacheck) — Lua linter (installed via lux)
   - [pre-commit](https://pre-commit.com/) — git hooks framework
   - [yq](https://github.com/mikefarah/yq) — YAML processor, used for workflow validation

3. Install the git hooks:

   ```bash
   pre-commit install --hook-dir .githooks
   pre-commit install --hook-dir .githooks --hook-type commit-msg
   ```

   These hooks auto-format Lua with stylua, lint with luacheck, run the test suite, validate generated vimdocs, and enforce the commit message format.

## Common commands

| Command | Purpose |
|---|---|
| `make test` | Run the full test suite |
| `make test path/to/file_spec.lua` | Run a single test file |
| `make check` | Run lint, format check, and docs check |
| `make docs` | Regenerate vimdocs from Lua annotations |
| `make bench` | Run performance benchmarks |
| `make debug` | Start a live-reload debug session |
| `pre-commit run --all-files` | Run all hooks manually on every file |

## Branch and commit conventions

This project follows [trunk-based development](https://trunkbaseddevelopment.com/). All work lands on `main`.

### Commit format

Every commit must follow [Conventional Commits](https://www.conventionalcommits.org/) and include a `Co-authored-by:` trailer identifying the AI tool or editor that assisted. We use `Co-authored-by:` (instead of the emerging `Assisted-by:` standard) so that GitHub can render a co-author avatar when the email is linked to a GitHub account.

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
Co-authored-by: <tool>[(<model>)] <email>
```

Rules:

- Use the imperative mood: "add feature" not "added feature".
- Start the description with a lowercase letter and do not end it with a period.
- Keep the first line under 72 characters.
- Use one of the valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Use a valid scope such as `components`, `hooks`, `fiber`, `buffer`, `layout`, `docs`, `build`, `tests`, or `agents`.
- End the message with a `Co-authored-by:` trailer naming the AI tool or editor and, when relevant, the model. For example: `Co-authored-by: OpenCode (kimi-k2.7-code) <noreply@opencode.ai>`.
- Use the email convention adopted by each tool. Known examples:
  - **Claude / Claude Code:** `Claude <noreply@anthropic.com>`
  - **GitHub Copilot:** `Copilot <copilot@github.com>`
  - **Cursor:** `Cursor <cursoragent@cursor.com>`
  - **OpenCode:** `OpenCode <noreply@opencode.ai>`
- Human-only commits can omit the trailer. If a commit was assisted by an AI, it must include the trailer.

Good example:

```
feat(components): add Input component with validation

Co-authored-by: OpenCode (kimi-k2.7-code) <noreply@opencode.ai>
```

## How to add a new component

1. Create `lua/ascii-ui/components/<name>.lua`.
2. Use `createComponent` to register it:

   ```lua
   local createComponent = require("ascii-ui.utils.create-component")

   local function MyComponent(props)
       local Segment = require("ascii-ui.buffer.segment")
       return { Segment:new({ content = props.text }):wrap() }
   end

   return createComponent("MyComponent", MyComponent, { text = "string" })
   ```

3. Export it from `lua/ascii-ui/components/init.lua`.
4. Add tests in `tests/unit/components/<name>_spec.lua`.
5. Add an example in `examples/` if it helps users understand the component.
6. Update `doc/ascii-ui.txt` by running `make docs` after changing public API annotations.

## How to add a new hook

1. Create `lua/ascii-ui/hooks/<name>.lua` following the existing hook patterns.
2. Export it from `lua/ascii-ui/hooks/init.lua`.
3. Add tests in `tests/unit/hooks/<name>_spec.lua`.
4. Document behavior in LuaCATS annotations so `make docs` picks it up.

## Testing requirements

- The test framework is [mini.test](https://nvim-mini.org/mini.nvim/readmes/mini-test) (Busted-style `describe`/`it`, see `scripts/minimal_init.lua`).
- Every new component or hook needs unit tests.
- Every bug fix should include a regression test.
- Run `make test` before pushing.
- Benchmarks live in `tests/bench/` and include hard budget assertions.

## Code of conduct

Be respectful, constructive, and patient. A formal `CODE_OF_CONDUCT.md` is coming soon; until then, treat others as you would want to be treated and assume good intent.

## Getting help

- Read the [README](./README.md) and the [docs](./docs/).
- Open a [discussion](https://github.com/ascii-ui/ascii-ui.nvim/discussions) for questions.
- Open an issue for bugs or feature requests.

## Agent contributors

If you are an AI agent, install the official skill for this project:

```sh
npx skills add ascii-ui/agent-skills --skill ascii-ui-nvim
```

It covers component patterns, hooks, conventions, and common pitfalls.
