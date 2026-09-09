# AGENTS.md

> **Agentic Development**: Since August 8, 2026, this project uses a multi-agent system for development. See `.opencode/agents/` for specialized agents (ascii-ui-dev, nvim-docs-researcher, convention-reviewer, agent-teacher).

## Commit Convention

**MANDATORY**: All commits MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. No exceptions.

This project enforces conventional commits to enable automated changelogs, semantic versioning, and clear commit history. Every commit message must conform to this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
Co-authored-by: <agent-name> [(<tool>)] <<agent-name>@ascii-ui.org>
```

### Format Rules

#### Type (required)

Must be one of the following. No other types allowed.

| Type | When to use |
|------|-------------|
| `feat` | A new feature (user-facing or API-visible) |
| `fix` | A bug fix |
| `docs` | Documentation only changes (Lua annotations, vimdocs, README, comments explaining *why*) |
| `style` | Code style changes that do not affect meaning (formatting, missing semicolons, whitespace) |
| `refactor` | Code restructuring that neither fixes a bug nor adds a feature (imports, folder moves, code organization). **NOT** for docs or agent changes |
| `perf` | A code change that improves performance |
| `test` | Adding missing tests or correcting existing tests |
| `build` | Changes that affect the build system or external dependencies (`lux.toml`, Makefile) |
| `ci` | Changes to CI configuration files and scripts (GitHub Actions) |
| `chore` | Maintenance tasks that don't fit other types (agent files, config, tooling). **All agent-related changes MUST use `chore` with scope `agents`** |
| `revert` | Reverts a previous commit |

#### Scope (required)

The area of the codebase affected. Must be lowercase, single word or hyphenated.

**Valid scopes for this project:**

| Scope | What it covers |
|-------|---------------|
| `components` | Built-in components (Paragraph, Button, Box, Select, etc.) |
| `hooks` | Hook implementations (useState, useEffect, useReducer, etc.) |
| `fiber` | Fiber reconciler and fibernode |
| `buffer` | Buffer rendering primitives (Segment, BufferLine, Buffer) |
| `layout` | Layout primitives (Row) |
| `window` | Neovim floating window viewport |
| `viewports` | Viewport implementations |
| `mount` | Component mounting and render loop |
| `events` | EventBus |
| `config` | Configuration |
| `utils` | Utility modules |
| `tests` | Test infrastructure and helpers |
| `bench` | Benchmarks |
| `docs` | Documentation **content** only (README, vimdocs, Lua annotations). NOT for doc generation scripts — those go in `build` |
| `agents` | Agent files, conventions, and configuration (MUST use with `chore` type) |
| `build` | Build system, Makefile, lux.toml, **scripts/** (including gendocs.lua) |
| `ci` | CI/CD configuration |

If a change spans multiple scopes, pick the most significant one or split into multiple commits.

#### Common Scope Mistakes

| ❌ Wrong | ✅ Correct | Why |
|----------|-----------|-----|
| `fix(docs):` for gendocs.lua changes | `fix(build):` | Scripts are build system, not docs content |
| `docs(codebase):` for comment changes | `docs:` or `refactor:` | Lua annotations → `docs`; code comments → `refactor` |
| `fix(ci):` for Makefile changes | `fix(build):` | Makefile is build system, not CI |
| `feat(tests):` for test infra | `feat(tests):` | ✅ This one is correct |

**Rule of thumb**: `docs` = user-facing documentation files. `build` = scripts, Makefile, tooling that generates/validates docs.

#### Description (required)

- **Imperative mood**: "add feature" not "added feature" or "adds feature"
- **Lowercase first letter**: "add Input component" not "Add Input component"
- **No period at the end**: "add Input component" not "add Input component."
- **Max 72 characters**: Keep it concise and scannable
- **Explain WHAT, not WHY**: The description explains what changed; the body explains why

#### Body (optional)

- Separated from description by a blank line
- Explains **what** and **why**, not **how**
- Wrap at 72 characters
- Use for complex changes that need context beyond the description

#### Footer (optional)

- Separated from body (or description) by a blank line
- Used for breaking changes and issue references
- Format: `Token: value` or `Closes #123`

### Breaking Changes

A breaking change MUST be indicated by:

1. `!` after the type/scope: `feat(components)!: remove deprecated prop`
2. OR `BREAKING CHANGE:` in the footer:

```
feat(components): redesign Select component API

BREAKING CHANGE: `options` prop renamed to `items`. Migration required.

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

### Agent attribution (required)

Every commit MUST include a `Co-authored-by:` trailer identifying which agent made the commit and which AI tool or editor was used. We deliberately use `Co-authored-by:` rather than the emerging `Assisted-by:` standard so that GitHub can render a co-author avatar when the email is linked to a GitHub account.

- `ascii-ui-dev` — Primary development agent
- `nvim-docs-researcher` — Documentation research agent
- `convention-reviewer` — Convention validation agent
- `agent-teacher` — Meta-learning agent

### Issue References

When a commit relates to an issue, add a closing keyword in the footer:

```
feat(components): add Input component with validation

Closes #42

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

**Closing keywords:**
- `Closes #123`, `Fixes #123`, `Resolves #123` — only when the commit **completely solves** the issue
- `WIP #123` or `Progress on #123` — for work-in-progress
- `Related to #123` — when related but doesn't solve the issue

**Important:** Always confirm with the user before using closing keywords.

### Good vs Bad Examples

✅ **Good:**
```
feat(components): add Input component with validation

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

✅ **Good:**
```
fix(hooks): prevent useEffect from firing on unmounted components

The effect callback was being invoked after component unmount
when async operations resolved. Add a mounted ref guard.

Fixes #23

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

✅ **Good:**
```
chore(agents): update convention-reviewer checklist

Co-authored-by: agent-teacher (opencode) <agent-teacher@ascii-ui.org>
```

❌ **Bad — missing type:**
```
add Input component

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

❌ **Bad — wrong mood:**
```
feat(components): added new Input component

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

❌ **Bad — uppercase first letter:**
```
feat(components): Add new Input component

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

❌ **Bad — period at end:**
```
feat(components): add new Input component.

Co-authored-by: ascii-ui-dev (opencode) <ascii-ui-dev@ascii-ui.org>
```

❌ **Bad — missing agent attribution:**
```
feat(components): add new Input component
```

❌ **Bad — wrong type for agent changes:**
```
refactor(agents): update convention-reviewer checklist

Co-authored-by: agent-teacher (opencode) <agent-teacher@ascii-ui.org>
```
(Should be `chore(agents):`)

## Trunk-Based Development

This project follows trunk-based development. All work happens on `main` branch directly.

### Rules

1. **Tests must pass** - Never commit if tests are failing
2. **No --no-verify** - Always run pre-commit hooks
3. **Small commits** - Keep changes atomic and focused
4. **Pull before push** - Always `git pull` before pushing
5. **Red pipeline = STOP** - If main pipeline is red, all agents stop current work
6. **Commit ASAP** - Commit the minimal significant change as soon as it works
7. **TDD first** - Write tests first, then implement (red-green-refactor)

### Commit ASAP

Commit as soon as you have a minimal significant change working with its tests:
- Don't accumulate large changes
- One feature/fix per commit
- Include tests with the change
- If it works and has tests, commit it

### TDD Workflow (Baby Steps)

Follow test-driven development with small incremental steps:

1. **Red** - Write a failing test for the smallest possible behavior
2. **Green** - Write the minimal code to make the test pass
3. **Refactor** - Clean up while tests still pass
4. **Repeat** - Add the next small behavior

**Baby steps means:**
- One assertion at a time
- One function at a time
- Don't skip ahead or implement multiple things at once
- Let the tests guide the design

### When Pipeline is Red

**CRITICAL**: If the main branch pipeline is failing:

1. **All agents stop** - Pause whatever you're doing
2. **One agent fixes** - Designate one agent to investigate and fix the issue
3. **No new features** - Do not commit new code until pipeline is green
4. **Priority #1** - Fixing the pipeline takes precedence over all other work

**Workflow when pipeline is red:**
```bash
# Check if main is failing
git checkout main
git pull
make test

# If tests fail:
# 1. All agents stop their current tasks
# 2. ascii-ui-dev (or designated agent) investigates
# 3. Fix the issue on main (or WIP branch if complex)
# 4. Verify tests pass
# 5. Only then resume normal work
```

### When Tests Fail

If you need to commit work but tests are failing:
- **Do NOT** use `--no-verify` to bypass hooks
- **Do NOT** commit to main with failing tests
- **Instead**: Create a draft PR or WIP branch
  - `git checkout -b wip/feature-name`
  - Push the branch
  - Open a draft PR for review
  - Fix tests before merging to main

### Workflow

```bash
# Standard workflow
git fetch origin
git rebase origin/main
# Make changes
make check
make test
git add .
git commit -m "type(scope): description\n\nCo-authored-by: agent-name (tool) <agent-name@ascii-ui.org>"
git push

# If tests fail, use a WIP branch
git checkout -b wip/broken-feature
git push -u origin wip/broken-feature
# Open draft PR on GitHub
```

## Project Overview

ascii-ui.nvim is a React-like UI framework for Neovim plugins, written in Lua. It provides functional components, hooks (`useState`, `useEffect`, `useReducer`, etc.), a fiber-based reconciler, built-in components (`Paragraph`, `Button`, `Box`, `Select`, `Slider`, `Checkbox`, `Tree`, `Input`), and layout primitives (`Row`). Components render to Neovim floating windows or terminal stdout.

## Commands

| Command | Purpose |
|---|---|
| `make test` | Build + run full test suite |
| `make test path/to/file_spec.lua` | Run a single test file |
| `make check` | Lint (luacheck via lux), format check (stylua), docs check |
| `make docs` | Regenerate vimdocs from Lua annotations |
| `make bench` | Run performance benchmarks |
| `make debug` | Live-reload debug session |
| `pre-commit run --all-files` | Run all pre-commit hooks on all files |
| `pre-commit run --files <files>` | Run hooks on specific files |

**Pre-commit hooks run automatically on `git commit` — no need to manually run `make check` or `make test` before committing.**

### Pre-commit Hooks

This project uses [pre-commit](https://pre-commit.com/) to automatically run checks before each commit. The hooks are configured in `.pre-commit-config.yaml` and include:

- **stylua**: Auto-formats Lua files
- **luacheck**: Lints Lua files
- **check-docs**: Validates vimdocs are up to date (only on `lua/ascii-ui/**/*.lua` changes)
- **check-workflows**: Validates GitHub Actions YAML (only on `.github/workflows/*.yml` changes)
- **test**: Runs the test suite
- **commit-msg**: Validates conventional commit format (MANDATORY — rejects invalid messages)
- **check-no-print**: Warns about `print()` statements in production code (non-blocking)

**Setup**: Install pre-commit hooks with:
```bash
pre-commit install --hook-dir .githooks
pre-commit install --hook-dir .githooks --hook-type commit-msg
```

This uses the existing `.githooks/` directory (configured via `core.hooksPath`). The pre-commit hook runs on `git commit`; the commit-msg hook validates the message format.

**Note**: `make check` still works and runs the same checks (without auto-formatting). Pre-commit is an addition that provides auto-formatting and runs on staged files only.

### Commit Message Validation

The `commit-msg` hook enforces conventional commits format automatically. Commits without proper format are rejected.

**Required format:**
```
type(scope): description

Co-authored-by: <agent-name> [(<tool>)] <<agent-name>@ascii-ui.org>
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Valid agents:** `ascii-ui-dev`, `nvim-docs-researcher`, `convention-reviewer`, `agent-teacher`, `task-scheduler`, `contributor`

**Rules:**
- Scope is optional but must be lowercase if present
- Description must start with lowercase letter
- Description must not end with period
- First line must be 72 characters or less
- Must include a `Co-authored-by:` trailer naming the agent and AI tool/editor

### Trusting Pre-commit Hooks

**Philosophy**: Pre-commit hooks run automatically on `git commit`. They validate:
- Code formatting (stylua auto-fixes)
- Linting (luacheck)
- Tests (make test)
- Docs validation (check-docs)
- Commit message format (commit-msg)

**What this means for agents:**
- ✅ **DO**: Just commit. Pre-commit will catch issues.
- ✅ **DO**: If pre-commit fails, read the error and fix it.
- ❌ **DON'T**: Manually run `make check` before committing — pre-commit does this.
- ❌ **DON'T**: Manually run `make test` before committing — pre-commit does this.
- ❌ **DON'T**: Worry about missing formatting or linting issues — stylua auto-fixes, luacheck catches the rest.

**Exception**: If you're debugging a complex issue and want to verify tests pass before committing, you CAN run `make test` manually. But for normal workflow, trust pre-commit.

## Architecture

### Source layout

All source lives under `lua/ascii-ui/`. Modules are required with full dotted paths: `require("ascii-ui.buffer.segment")`.

```
lua/ascii-ui/
├── init.lua              # Public API
├── buffer/               # Buffer rendering primitives (Segment, BufferLine, Buffer)
├── components/           # Built-in components (Paragraph, Button, Box, Select, etc.)
├── hooks/                # React-like hooks (useState, useEffect, useReducer, etc.)
├── layout/               # Layout primitives (Row)
├── utils/                # Utility modules
├── viewports/            # Viewport implementations (StdoutViewport)
├── window/               # Neovim floating window viewport
├── fiber.lua             # Fiber reconciler
├── fibernode.lua         # Fiber tree node
├── mount.lua             # Component mounting + render loop
├── events.lua            # EventBus
├── config.lua            # Default config
└── ...
```

### Test layout

Tests mirror source structure under `tests/`:

```
tests/
├── unit/                 # Unit tests (mirror lua/ascii-ui/ structure)
│   ├── components/       # Component tests
│   └── hooks/            # Hook tests
├── e2e/                  # End-to-end interaction tests
├── bench/                # Benchmarks with hard budget assertions
└── util/                 # Test fixtures and helpers
```

### Key modules

- **`fiber.lua` / `fibernode.lua`** — React-like fiber reconciler. Depth-first tree traversal, reconciliation, diffing.
- **`mount.lua`** — Mounts components to viewports, manages the render loop.
- **`buffer/`** — `Segment` (styled text unit), `BufferLine` (line of segments), `Buffer` (collection of lines).
- **`components/`** — Each component in its own file, registered via `createComponent(name, fn, types)`.
- **`hooks/`** — Each hook in its own file. Follow React naming: `useState`, `useEffect`, etc.

## Conventions

### Code style

- **Formatter**: StyLua (config in `.stylua.toml`) — tabs, width 4, double quotes, collapse simple statements off
- **Linter**: luacheck (config in `.luacheckrc`)
- **Type annotations**: LuaCATS/LuaLS format, extensive use of `@class`, `@field`, `@param`, `@return`, `@enum`
- **Type prefix**: `ascii-ui.` for all type annotations (e.g., `ascii-ui.Segment`, `ascii-ui.Config`)

### Naming

- **Filenames**: `snake_case.lua` (components use hyphens in `create-component.lua` — outlier)
- **Classes**: PascalCase (`FiberNode`, `Buffer`, `Segment`, `Window`, `EventBus`)
- **Components**: PascalCase strings (`"Paragraph"`, `"Button"`, `"Select"`)
- **Hooks**: camelCase (`useState`, `useEffect`, `useReducer`)
- **Test files**: `*_spec.lua`

### Module pattern

Every class/module follows this structure:

```lua
local ModuleName = {}
ModuleName.__index = ModuleName

function ModuleName.new(opts)
    local state = { ... }
    setmetatable(state, ModuleName)
    return state
end

function ModuleName.is_module(obj)
    return type(obj) == "table" and obj.__index == ModuleName.__index
end

return ModuleName
```

### Component pattern

```lua
local createComponent = require("ascii-ui.utils.create-component")

local function MyComponent(props)
    return { Segment:new({ content = props.text }):wrap() }
end

return createComponent("MyComponent", MyComponent, { text = "string" })
```

Components return arrays of `FiberNode` or `BufferLine` objects. Use `Segment:wrap()` to wrap a segment in a `BufferLine`.

### Subdirectory `init.lua` pattern

Directories with multiple files expose an `init.lua` that re-exports the public API (e.g., `buffer/init.lua`, `components/init.lua`, `hooks/init.lua`).

## Testing

- **Framework**: Plenary.nvim test harness (Busted-style `describe`/`it`/`assert`)
- **Assertions**: `luassert` — `assert.are.same`, `assert.is_true`, etc.
- **Every test file** must start with `pcall(require, "luacov")` (enforced by `tests/arch_spec.lua`)
- **E2E tests** use `plenary.async.tests.it` for async testing
- **Benchmarks** have hard budget assertions to catch performance regressions

## Documentation

- Vimdocs (`doc/ascii-ui.txt`) are auto-generated from Lua annotations via `mini.doc`
- Run `make docs` after changing public API annotations
- Run `make docs-check` to verify docs are up to date (part of `make check`)

## Dependencies

- **Package manager**: Lux (`lux.toml`)
- **Runtime**: Lua 5.1 (Neovim's embedded Lua)
- **Test dependency**: `plenary.nvim` (cloned automatically by `scripts/test`)
- **Dev tools**: `stylua`, `luacheck`, `nvim`, `git`

## Commit Policy

**MANDATORY**: Commit immediately after implementing changes.

- Do not accumulate multiple changes
- Do not leave code uncommitted "for later"
- If tests pass and change is complete → commit NOW
- If tests fail → fix or use WIP branch

This reinforces the "Commit ASAP" rule above. Agents must not sit on completed work.

## Skill Awareness

Agents load ONLY project-local skills (from `.opencode/skills/` or project-specific).

Ignore global skills from `available_skills` unless explicitly requested by user.

### Project-Local Skills

Check `.opencode/skills/` for project-specific skills. Load when task matches skill scope.

Global skills (listed in `available_skills` by the runtime) are general-purpose and not project-aware. Prefer project-local skills that understand ascii-ui conventions, architecture, and patterns.

## Difficulty Reporting

**MANDATORY**: After completing any task, agents must append a `## Difficulties` section to their result.

### Format

```markdown
## Difficulties

- [category] description | impact | workaround (if any)
```

### Categories

- `tool` — Tool/API didn't work as expected
- `instructions` — Agent instructions didn't cover the situation
- `context` — Needed info not available
- `permission` — Blocked by constraints
- `ambiguity` — Multiple valid interpretations
- `workaround` — Used hack or non-obvious solution
- `repeated` — Same friction encountered before

### Example

```markdown
## Difficulties

- [instructions] Unclear when to use useState vs useReducer | wasted time | checked tests
- [tool] stylua not found in PATH | had to use make check instead | ran make check
```

### Difficulty Flow

1. Each agent reports difficulties after task completion
2. `task-scheduler` forwards difficulties to `agent-teacher`
3. `agent-teacher` processes difficulties and updates agent instructions
4. Patterns become permanent improvements to the agent system

## Escalation Protocol

When agents are stuck or blocked, they must escalate rather than loop indefinitely.

### When to Escalate

1. **Timeout**: Task not progressing after multiple attempts
2. **Permission blocked**: Cannot complete due to access restrictions
3. **Repeated failures**: Same issue encountered 3+ times
4. **Unclear requirements**: Task scope or success criteria ambiguous
5. **Missing context**: Critical information not available

### Escalation Flow

```
Agent stuck
    ↓
Attempts fix (max 3 tries)
    ↓
Still stuck?
    ↓
Reports difficulty to task-scheduler
    ↓
task-scheduler evaluates
    ↓
├─► Can delegate to another agent? → Re-delegate
├─► Needs user input? → Escalate to user
└─► Agent instruction issue? → Forward to agent-teacher
```

### Escalation Format

```markdown
## Escalation

**Agent**: [agent-name]
**Issue**: [what's wrong]
**Attempts**: [what's been tried]
**Suggested Action**: [what should happen next]
```

## Agent Communication Protocol

All agent delegation must use structured prompts via the task tool.


### Delegation Format

```markdown
## Task Delegation

**Agent**: [agent-name]
**Task**: [brief description]
**Context**: [relevant background]
**Skills**: [suggested skills to load]
**Priority**: [high/medium/low]
**Workspace**: /tmp/ascii-ui-[agent-name]/ (for parallel work)

### Requirements

0. Before starting implementation, fetch and rebase from origin/main:
   `git fetch origin && git rebase origin/main`
1. [specific requirement 1]
2. [specific requirement 2]
3. Work in isolated workspace under /tmp (if parallel execution)
4. Create PR when complete
5. Wait for review and merge to main
6. Verify pipeline is green on main after merge before reporting completion

### Success Criteria

- [ ] [criterion 1]
- [ ] [criterion 2]
- [ ] Branch is up to date with origin/main (rebased)
- [ ] PR created and merged to main
- [ ] Pipeline is green on main after merge

### Difficulty Reporting

After completion, append `## Difficulties` section to your result.
```

### Result Format

Agents must report results in this structure:

```markdown
## Task Result

### Summary

[Brief description of what was done]

### Changes Made

1. [change 1]
2. [change 2]

### Verification

- [ ] Tests pass
- [ ] Linting passes
- [ ] Documentation updated (if applicable)
- [ ] PR created and merged to main
- [ ] Pipeline is green on main after merge

### Difficulties

- [category] description | impact | workaround
```

## Progress Tracking

task-scheduler tracks all delegated work and reports status.

### Status Categories

- **Active**: Currently being worked on (max 2 concurrent)
- **In Review**: PR created, awaiting review and merge
- **Completed**: Merged to main AND pipeline is green on main
- **Queued**: Waiting for agent availability
- **Blocked**: Cannot proceed due to external factor

### Status Report Format

```markdown
## Task Status

### Active (X/2)
1. **[agent]**: [task] - [status]

### In Review
- [task] - [PR link, awaiting review/merge]

### Completed (merged to main + pipeline green)
- [task] - [result, merged, pipeline green]

### Queued
- [task] - [reason queued]

### Blocked
- [task] - [blocker]
```

### Issue Updates

When tasks complete, task-scheduler can create new issues/PRs directly. For closing or editing existing ones, task-scheduler informs user:
- "Issue #123 completed. Suggest closing."
- "PR #456 ready for review."

task-scheduler cannot edit or close existing issues/PRs. User must act on those suggestions.

## Agent Capabilities

### Permission Matrix

| Agent | Edit | Bash | Scope |
|-------|------|------|-------|
| task-scheduler | ❌ | `gh` (read + create issues/PRs) | Coordination |
| ascii-ui-dev | ✅ (except `.opencode/`) | ✅ | Implementation |
| nvim-docs-researcher | ❌ | ❌ | Read-only research |
| convention-reviewer | ❌ | `make check/test`, `git status/diff` | Verification |
| agent-teacher | `.opencode/agents/*`, `.opencode/skills/*`, `opencode.json` | ✅ | Agent improvement |

### Agent Specializations

- **task-scheduler**: Reads and creates GitHub issues/PRs, delegates work, tracks progress
- **ascii-ui-dev**: Implements features, fixes bugs, writes tests, commits code
- **nvim-docs-researcher**: Finds Neovim API documentation, explains APIs
- **convention-reviewer**: Reviews code against conventions, approves/rejects commits
- **agent-teacher**: Updates agent instructions, creates skills, processes difficulties

## Skill Creation

agent-teacher can create project-local skills in `.opencode/skills/`.

### When to Create Skills

1. Repeated pattern across multiple tasks
2. Specialized domain knowledge needed
3. Complex multi-step procedures
4. Agents report missing knowledge in difficulties

### Skill Structure

```
.opencode/skills/my-skill/
├── SKILL.md          # Main instructions
├── examples/         # Example files (optional)
└── scripts/          # Helper scripts (optional)
```

See `.opencode/skills/README.md` for full documentation.

## Agent Creation

agent-teacher can create new specialized agents when gaps are identified.

### When to Create Agents

1. Current agents cannot handle the task type
2. Task requires specialized knowledge
3. Repeated delegation to same domain

### Agent Creation Process

1. Identify gap in current agent capabilities
2. Define agent role, capabilities, constraints
3. Create `.opencode/agents/<name>.md`
4. Update `opencode.json` with permissions
5. Document in `AGENTS.md`
6. Test on sample tasks
7. Commit immediately

## Documentation Sync

When changes are made to `lua/ascii-ui/` or `doc/ascii-ui.txt`, the Docusaurus documentation at [ascii-ui-docs](https://github.com/ascii-ui/ascii-ui-docs) may need to be updated.

### Automatic Notifications

A GitHub Actions workflow (`.github/workflows/docs-sync.yml`) automatically creates an issue in the ascii-ui-docs repo when docs-relevant files change on main.

### Manual Sync

To manually update the docs:

```bash
# Clone or update the docs repo
./scripts/sync-docs.sh

# Or if you have it locally:
cd /path/to/ascii-ui-docs
git pull

# Make changes to docs/
# ...

# Verify build
npm run build

# Commit and create PR
git add .
git commit -m "docs: update for latest changes"
git push
gh pr create
```

### What to Update

- **API changes** (lua/ascii-ui/) → Update component/hook documentation
- **New features** → Add new documentation pages
- **Breaking changes** → Update migration guides
- **Vimdocs changes** (doc/ascii-ui.txt) → Review if Docusaurus docs need updates
