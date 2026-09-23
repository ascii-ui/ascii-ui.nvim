# Expected Behavior

## Agent Actions

1. **Run git status**: Agent checks what files changed
2. **Read changed files**: Agent reads each modified file
3. **Run make check**: Agent verifies linting and formatting
4. **Run make test**: Agent verifies tests pass
5. **Apply checklist**: Agent goes through review checklist
6. **Generate report**: Agent produces structured review output
7. **Give verdict**: Agent explicitly approves or rejects

## Expected Commands Run

```bash
git status                   # See what changed
git diff                     # See specific changes
make check                   # Verify linting/formatting
make test                    # Verify tests pass
```

## Expected Output Format

```
## Convention Review

### Summary
- ✅ Passed: X checks
- ❌ Failed: Y checks

### Violations
[If any, with file:line references]

### Recommendations
[If any]

### Verdict
✅ APPROVED - Ready to commit
OR
❌ REJECTED - Fix violations before committing
```

## Expected Review Checklist Items

- [ ] StyLua compliance
- [ ] luacheck clean
- [ ] Naming conventions (snake_case files, PascalCase classes)
- [ ] Module pattern (__index, new(), is_module())
- [ ] Type annotations (LuaCATS format)
- [ ] Test requirements (mini.test framework, no plenary/luassert/luacov)
- [ ] Documentation (if public API)
- [ ] File organization (correct directories)
