# Validation Steps

## 1. Check Root Cause Analysis

Agent should identify:
- Instructions lacked clear decision criteria
- No guidance on when to choose useState vs useReducer
- Agent had to guess or check tests for examples

**Expected**: Agent explains why the difficulty occurred

## 2. Check Instructions Updated

Agent should add to ascii-ui-dev.md:
- Clear "when to use useState" criteria
- Clear "when to use useReducer" criteria
- Decision rules or heuristics

**Expected**: Instructions contain explicit guidance

## 3. Check Guidance Quality

Guidance should be:
- Specific (not vague)
- Actionable (clear decision criteria)
- Complete (covers common cases)

**Expected**: Guidance helps agent make correct choice

## 4. Check Changelog Entry

Agent should add changelog entry:
- Date
- What was updated
- Why (brief reason)

**Expected**: Changelog reflects the change

## 5. Check Commit

Agent should commit with:
- Proper format: `chore(agents): ...`
- Agent attribution: `Co-authored-by: agent-teacher (opencode) <agent-teacher@ascii-ui.org>`
- Clear description

**Expected**: Commit follows convention

## Validation Checklist

- [ ] Root cause identified
- [ ] Instructions updated with decision criteria
- [ ] Guidance is clear and actionable
- [ ] Changelog entry added
- [ ] Changes committed properly
- [ ] Commit message follows convention

## Common Failures

### Agent didn't identify root cause
- **Symptom**: Update doesn't address actual issue
- **Cause**: Agent didn't analyze difficulty properly
- **Fix**: Add root cause analysis step to workflow

### Agent added vague guidance
- **Symptom**: "Use useState for simple things, useReducer for complex things"
- **Cause**: Agent didn't provide specific criteria
- **Fix**: Require explicit decision rules in instructions

### Agent didn't update changelog
- **Symptom**: No changelog entry
- **Cause**: Agent forgot documentation step
- **Fix**: Add changelog requirement to update process

### Agent didn't commit
- **Symptom**: Changes not committed
- **Cause**: Agent forgot commit step
- **Fix**: Reinforce "commit immediately" policy
