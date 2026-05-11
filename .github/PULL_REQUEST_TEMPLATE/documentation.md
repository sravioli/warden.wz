### Summary

Describe the Warden documentation change.

### Documentation Changed

List the README, contributing guide, examples, issue templates, pull request
templates, or annotation docs changed by this pull request.

### Reader Impact

Explain who benefits from this documentation change:

- Plugin authors defining schemas.
- Users configuring a plugin that uses Warden.
- Contributors changing Warden internals.

### Examples Touched

```lua
-- schema, validation, or result example changed by this pull request
```

### Behavior Change

- [ ] Documentation only
- [ ] Documents an existing behavior
- [ ] Documents a new behavior

If this documents a new behavior, link to the implementation pull request or
commit.

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
