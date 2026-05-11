# warden.wz Contributing Guide

Thank you for taking the time to improve warden.wz.

Warden is a schema validation library for WezTerm plugin and configuration
tables. Contributions should keep that scope tight: validate input, normalize
defaults, report clear issues, and avoid surprising side effects.

## What We Accept

- Bug fixes for schema validation, result reporting, or assertion helpers.
- New schema constructors or constraints that are useful for WezTerm plugin
  configuration.
- Documentation improvements for configuration validation workflows.
- Tests that cover real plugin-author usage.

At this time, Warden does not aim to be a full Zod clone. Features such as async
validation, codecs, JSON Schema export, or static type inference should start as
a discussion before implementation.

## Local Setup

Clone the repository and install the Lua tooling used by the checks:

```sh
git clone https://github.com/sravioli/warden.wz.git
cd warden.wz
```

The test suite uses Busted. Linting uses luacheck, Selene, and StyLua.

## Development Workflow

1. Create a branch for the change.
2. Add or update tests for the behavior.
3. Keep the public API small and documented.
4. Run the checks before opening a pull request.
5. Use a Conventional Commit message.

Recommended checks:

```sh
busted --verbose
luacheck plugin spec
stylua --check plugin spec
selene --display-style=quiet plugin
```

## Design Guidelines

- Prefer schema-owned defaults over separate default config tables.
- Do not add config merge behavior; callers own merging.
- Keep validation non-mutating.
- Make `safe_parse()` useful for plugins that should warn and keep running.
- Keep `parse()` strict for callers that want hard failure.
- Return precise issue paths such as `window.opacity`.
- Keep logging dependency-free; injected loggers and WezTerm logging are enough.

## Tests

Tests should describe the user-facing behavior:

- Required and optional fields.
- Defaults applied to normalized output.
- Unknown-key policies.
- Nested object paths.
- Declarative schemas compiled with `warden.compile`.
- Result formatting and logging.
- Assertion helper compatibility.

When fixing a bug, add a regression test that fails without the fix.

## Documentation

Update `.github/readme.md` whenever public API, defaults, or validation behavior
changes. Examples should focus on plugin configuration because that is Warden's
primary use case.

## License

By contributing, you agree that your code is licensed under the repository's
code license and your documentation is licensed under the repository's
documentation license.
