# Project-Local Skills

This directory contains skills specific to ascii-ui.nvim project.

## What is a Skill?

A skill is a specialized instruction set that provides agents with domain-specific knowledge and workflows. Skills are loaded on-demand when a task matches the skill's scope.

## Available Skills

- [`internal ascii-ui opensource skills`](./internal%20ascii-ui%20opensource%20skills/SKILL.md) — Workflow for working with the ascii-ui.nvim launch project board: picking up tasks, adding evidence, and moving items to Human check.

## Creating a New Skill

1. Create a new directory: `.opencode/skills/<skill-name>/`
2. Add `SKILL.md` with skill instructions
3. Optionally add supporting files (scripts, examples, etc.)

### Skill Structure

```
.opencode/skills/my-skill/
├── SKILL.md          # Main skill instructions
├── examples/         # Example files (optional)
└── scripts/          # Helper scripts (optional)
```

### SKILL.md Format

```markdown
# Skill Name

Brief description of what this skill covers.

## When to Use

- Trigger condition 1
- Trigger condition 2

## Instructions

Detailed workflow instructions for the agent.

## Examples

Code examples or usage patterns.

## Related Skills

- Other skill 1
- Other skill 2
```

## Skill Creation Workflow

1. **Identify pattern**: Repeated task or specialized knowledge needed
2. **Propose skill**: Document what the skill should cover
3. **Create skill**: agent-teacher creates skill directory and files
4. **Test skill**: Agents use skill on relevant tasks
5. **Iterate**: Refine based on agent feedback

## Permissions

- **agent-teacher**: Can create and modify skills
- **Other agents**: Read-only access, load skills as needed

## Integration with Agents

Agents should:
1. Check this directory for relevant skills before starting work
2. Load skills using the `skill` tool when task matches skill scope
3. Report difficulties if skills don't cover the domain

## Changelog

- 2026-09-09: Added `internal ascii-ui opensource skills` project board workflow skill
- 2026-08-08: Initial skills directory created
