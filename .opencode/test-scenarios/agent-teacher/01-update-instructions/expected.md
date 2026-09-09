# Expected Behavior

## Agent Actions

1. **Read difficulty report**: Agent understands the reported issue
2. **Read current instructions**: Agent reads ascii-ui-dev.md to see current state management guidance
3. **Identify gap**: Agent finds where useState vs useReducer guidance is missing or unclear
4. **Write update**: Agent adds clear decision criteria
5. **Add changelog**: Agent documents the change
6. **Commit**: Agent commits the instruction update

## Expected Update Content

The instructions should include guidance like:

```markdown
### State Management

**Use `useState` when:**
- Simple state (single value or small object)
- State updates are straightforward
- No complex state transitions

**Use `useReducer` when:**
- Complex state logic with multiple sub-values
- Next state depends on previous state
- Multiple state updates that need to be coordinated
- State transitions follow a pattern (like a state machine)

**Decision criteria:**
- If you find yourself calling setState multiple times for related values → useReducer
- If state updates are independent → useState
- If you need to centralize state logic → useReducer
```

## Expected File Modified

- `.opencode/agents/ascii-ui-dev.md` - Updated state management section

## Expected Changelog Entry

```markdown
## Changelog

- 2026-08-08: Added clear guidance on useState vs useReducer decision criteria
```

## Expected Commit Message

```
chore(agents): clarify useState vs useReducer decision criteria

Add explicit guidance on when to use each hook based on difficulty
report from ascii-ui-dev.

Co-authored-by: OpenCode (kimi-k2.7-code) <noreply@opencode.ai>
```
