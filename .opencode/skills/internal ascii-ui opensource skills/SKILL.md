# Internal ascii-ui Open Source Skills

Workflow skill for agents working on the ascii-ui.nvim open source project board.

## When to Use

Load this skill when:
- You are about to work on a task from the ascii-ui project board.
- You need to check the project board status or columns.
- You have completed work and need to add evidence or move a task.

## Project Board

The org project is **"ascii-ui.nvim Launch"** (project number `1`):

```
https://github.com/orgs/ascii-ui/projects/1
```

Use `gh` to interact with it. The project ID is `PVT_kwDOEuR4lc4Bi8wO`.

## Column Definitions

| Column | Meaning | Who Moves Items |
|--------|---------|-----------------|
| **Todo** | Task hasn't been started. | Task scheduler / human |
| **Ready for agent** | Task is confirmed ready for an agent to pick up. | Task scheduler / human |
| **In Progress** | Task is actively being worked on. | Agent |
| **Human check** | Task performed by an agent. Requires human check to confirm it is done. Agent must add evidence. | Agent |
| **Done** | Task is completed and confirmed. | Human |

## Workflow

1. **Check the board** before starting work:
   ```bash
   gh project item-list 1 --owner ascii-ui --format json
   ```

2. **Pick a task** from **Ready for agent**. Read its full body and deliverables:
   ```bash
   gh api graphql -f query='query { node(id: "<item-id>") { ... on ProjectV2Item { content { ... on DraftIssue { title body } } } } }'
   ```

3. **Move it to In Progress** while working:
   ```bash
   gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwDOEuR4lc4Bi8wO", itemId: "<item-id>", fieldId: "PVTSSF_lADOEuR4lc4Bi8wOzhhy7Tg", value: { singleSelectOptionId: "47fc9ee4" } }) { projectV2Item { id } } }'
   ```

4. **Do the work**, commit, and push following project conventions (Conventional Commits, `[agent: <name>]` footer, trunk-based `main`).

5. **Add evidence** to the task description. Include:
   - Commit links
   - File links
   - A deliverables/evidence table
   - Any notes or blockers

   To update the body, use the draft issue content ID (prefixed with `DI_`):
   ```bash
   gh project item-edit --project-id PVT_kwDOEuR4lc4Bi8wO --id <DI_...> --title "<title>" --body "<evidence>"
   ```

6. **Move to Human check** when done:
   ```bash
   gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwDOEuR4lc4Bi8wO", itemId: "<item-id>", fieldId: "PVTSSF_lADOEuR4lc4Bi8wOzhhy7Tg", value: { singleSelectOptionId: "ee8ffdc3" } }) { projectV2Item { id } } }'
   ```

7. **Never move items to Done.** That column is owned by the human reviewer.

## Column Option IDs

| Column | Option ID |
|--------|-----------|
| Todo | `f75ad846` |
| Ready for agent | `e2aa49e2` |
| In Progress | `47fc9ee4` |
| Human check | `ee8ffdc3` |
| Done | `98236657` |

## Field IDs

| Field | ID |
|-------|-----|
| Status | `PVTSSF_lADOEuR4lc4Bi8wOzhhy7Tg` |
| Phase | `PVTSSF_lADOEuR4lc4Bi8wOzhhy7hY` |
| Track | `PVTSSF_lADOEuR4lc4Bi8wOzhhy7hc` |

## Evidence Template

Append this to the task body when moving to Human check:

```markdown
---

## Evidence

Commit: [short-sha](https://github.com/ascii-ui/ascii-ui.nvim/commit/<full-sha>)

| Deliverable | Evidence |
|-------------|----------|
| Deliverable 1 | Where and how it was implemented |
| Deliverable 2 | Where and how it was implemented |

Status: Ready for human review.
```

## Related Skills

- ascii-ui-nvim (global skill) — for component/hook implementation patterns
