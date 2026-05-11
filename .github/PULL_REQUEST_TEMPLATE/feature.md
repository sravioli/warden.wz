### Summary

Describe the new Warden feature and the user-facing validation workflow it
enables.

### Motivation

Explain why this belongs in warden.wz. Focus on schema validation for WezTerm
plugin or configuration tables.

### API Sketch

```lua
-- show intended schema usage
```

### Behavior

Describe how the feature behaves, including defaults, required or optional
values, validation issues, and result output.

### Compatibility

- [ ] Non-breaking
- [ ] Potentially breaking
- [ ] Breaking

If this is potentially breaking or breaking, explain the migration path.

### Tests

Describe the tests added or updated for this behavior.

### Documentation

Describe the README, contributing guide, examples, or annotation changes made for
this feature.

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
