### Summary

Describe the bug fixed in warden.wz and the user-visible behavior that changed.

### Reproduction

Provide the smallest schema and input that reproduced the issue.

```lua
-- schema and input that reproduced the bug
```

### Root Cause

Explain why validation, default normalization, issue reporting, parsing, or
assertion behavior was wrong.

### Fix

Describe the implementation change and why it fixes the problem.

### Regression Test

Describe the regression test added or updated.

### Compatibility Impact

- [ ] Non-breaking
- [ ] Potentially breaking
- [ ] Breaking

If this changes behavior intentionally, explain why the new behavior is correct.

### Checklist

- [ ] The change is scoped to warden.wz.
- [ ] Public API changes are documented, if applicable.
- [ ] Validation behavior is covered by tests, if applicable.
- [ ] Defaults remain schema-owned; no config merge behavior was added.
- [ ] User input remains non-mutating.
- [ ] `safe_parse()` remains non-throwing.
- [ ] Required checks pass:
  - [ ] `busted --verbose`
  - [ ] `luacheck .`
  - [ ] `stylua --check .`
  - [ ] `selene --display-style=quiet .`
