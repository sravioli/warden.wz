# warden.wz [![Release](https://img.shields.io/github/v/release/sravioli/warden.wz?style=flat&label=Release&logo=github)](https://github.com/sravioli/warden.wz/releases/latest)

<!-- [![Awesome](https://awesome.re/mentioned-badge.svg)](https://github.com/michaelbrusegard/awesome-wezterm) -->

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/tests.yaml?style=flat&label=Tests&logo=githubactions)](https://github.com/sravioli/warden.wz/actions/workflows/tests.yaml)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/lint.yaml?style=flat&label=Lint&logo=githubactions)](https://github.com/sravioli/warden.wz/actions/workflows/lint.yaml)
[![Coverage](https://img.shields.io/coverallsCoverage/github/sravioli/warden.wz?style=flat&label=Coverage&logo=coveralls)](https://coveralls.io/github/sravioli/warden.wz)
[![Code license](https://img.shields.io/badge/Code-GPL--2.0-blue?style=flat&logo=gnu)](../LICENSE)
[![Docs license](https://img.shields.io/badge/Docs-CC_BY--NC_4.0-blue?style=flat&logo=creativecommons)](../LICENSE-DOCS)

Validate and normalize [WezTerm](https://wezterm.org/) plugin configuration tables.

Declare accepted fields, defaults, constraints, and relationships in a schema.
Warden returns a copy with precise issue paths. You choose whether invalid
input produces a report or raises an error.

[Quick start](#quick-start) · [Usage](#usage) · [Configuration](#configuration) · [API reference](#api-reference) · [Troubleshooting](#troubleshooting) · [Development](#development) · [License](#license)

## Quick start

### Requirements

Requires **WezTerm [`20230320-124340-559cb7b0`](https://wezterm.org/config/lua/wezterm.plugin/require.html)
or newer** and Git. No other plugins, special fonts, or validation tools
are required.

### Install and run

Put this in `wezterm.lua`:

```lua
local wezterm = require "wezterm"
local warden = wezterm.plugin.require "https://github.com/sravioli/warden.wz"
local config = wezterm.config_builder()

local schema = warden.object {
  opacity = warden.number():range(0, 1):default(0.9),
}
local settings = schema:parse {}
config.window_background_opacity = settings.opacity

return config
```

Reload to apply opacity `0.9`. The schema fills the omitted value.
In an existing config, reuse its builder and apply validated settings before
the final return. For untrusted user options, prefer the reporting workflow
below instead of raising during config evaluation.

## Usage

### Report invalid user options

```lua
local schema = warden.object {
  theme = warden.string():not_empty(),
  title = warden.string():optional(),
}
local user_options = { theme = "wave", typo = true }
local result = schema:safe_parse(user_options)
result:log()
if result.ok then
  wezterm.log_info(result.value.theme)
end
```

By default, Warden warns about unknown object keys and keeps them in the output.
Warnings do not make `ok` false. Read `result.value` only when `ok` is true.
A failed result can contain partial normalized data.
Warden does not log automatically.

### Express relationships between fields

```lua
local target = warden.object {
  preset = warden.string():optional(),
  path = warden.string():optional(),
}
target:exactly_one_of { "preset", "path" }
local result = target:safe_parse { path = "theme.lua" }
result:log { detailed = true }
```

Relationship rules run after defaults, so defaulted values count as present.
`:when(field, expected, { required = {...}, forbidden = {...} })` uses
equality against the parsed field value, not a predicate.

### Compile a data-driven schema

```lua
local schema = warden.compile {
  type = "object",
  fields = {
    retries = { type = "integer", min = 0, max = 5, default = 2 },
  },
}
local settings = schema:parse {}
```

Declarative specs compile to the same mutable schema objects as the builder
API. Use `fields`, `items`, `keys`, and `values` for compound types.
Enums, literals, and unions use `enum = {...}`, `literal = value`, and
`union = { specs... }`, not just a `type` string. See
[compile.lua](../plugin/warden/compile.lua) for the complete mapping.

## Configuration

### Example

There is no global setup function. Defaults belong to schemas. Parse and
logging options apply per call. To reject unknown keys:

```lua
local schema = warden.object {
  enabled = warden.boolean():default(true),
}
local result = schema:safe_parse({ enabled = true }, { unknown = "error" })
result:log { detailed = true }
```

### Options

#### Parsing and result logging

| Option      | Type                                  | Default  | Description                                                                                                  |
| ----------- | ------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------ |
| `unknown`   | `"keep"\|"warn"\|"error"\|"strip"`    | `"warn"` | Parse option: keep silently, warn and keep, fail, or remove unknown object keys. A schema's `:unknown` wins. |
| `drop_invalid` | `boolean`                          | `false`  | Parse option: remove each failing value and parse the rest again. `result.dropped` lists them; `result.input` is the cleaned input. |
| `detailed`  | `boolean`                             | `false`  | `result:log` option: emit one expanded report instead of one compact line per issue.                         |
| `error`     | `fun(message: string)`                | `nil`    | Error callback on the table passed directly to `result:log`. Called without `self`.                          |
| `warn`      | `fun(message: string)`                | `nil`    | Warning callback on the same table. Called without `self`.                                                   |
| `log_error` | `fun(message: string)`                | `nil`    | WezTerm-style alternative when `error` is absent.                                                            |
| `log_warn`  | `fun(message: string)`                | `nil`    | WezTerm-style alternative when `warn` is absent.                                                             |
| `log`       | `fun(level: string, message: string)` | `nil`    | Generic callback used when the level-specific callbacks are absent.                                          |

#### Assertion construction

Pass these to `warden.assert.new`. They do not configure schemas.

| Option                | Type                                       | Default                  | Description                                                                   |
| --------------------- | ------------------------------------------ | ------------------------ | ----------------------------------------------------------------------------- |
| `accumulate`          | `boolean`                                  | `false`                  | Collect failures until `throw` instead of invoking the handler immediately.   |
| `fail_fast`           | `boolean`                                  | `false`                  | Throw on the first accumulated failure.                                       |
| `silent`              | `boolean`                                  | `false`                  | Collect failures without invoking the handler. Callbacks/logging still run.   |
| `strict_mode`         | `boolean`                                  | `false`                  | Raise immediately, before accumulation. `silent` takes precedence.            |
| `lazy_eval`           | `boolean`                                  | `false`                  | After a failure, skip further bookkeeping and error handling.                 |
| `cache_type_checks`   | `boolean`                                  | `false`                  | Cache type-name lookups.                                                      |
| `prefix`              | `string?`                                  | `nil`                    | Prefix error messages.                                                        |
| `context`             | `string\|string[]?`                        | `nil`                    | Prepend context to messages.                                                  |
| `group_errors`        | `boolean`                                  | `false`                  | Prefix the assertion group name.                                              |
| `show_stack_trace`    | `boolean`                                  | `false`                  | Append a traceback. Requires Lua's `debug` library.                           |
| `max_message_length`  | `integer?`                                 | `nil`                    | Byte limit before appending `"..."`.                                          |
| `handler.handle`      | `fun(message: string, level: integer)`     | Computed raising handler | Error handler called without `self`. Custom handlers may return.              |
| `format_error.format` | `fun(error: table, config: table): string` | `nil`                    | Replace formatted error text. Called without `self`.                          |
| `on_error`            | `fun(error: table)`                        | `nil`                    | Failure callback before handler/collection.                                   |
| `logger.error`        | `fun(message: string)`                     | `nil`                    | Assertion diagnostic callback, called without `self`.                         |
| `metrics.record`      | `fun(event: string)`                       | `nil`                    | Optional metrics callback. Supplying a `metrics` table also enables counters. |

### Behavior and precedence

Fields are required unless optional or defaulted. Warden copies table defaults
and calls default functions for missing values, then validates the result.
It copies input rather than changing it and does not merge an external defaults
table with user data.

Schema modifiers mutate and return the same schema. Reusing a child schema
shares its later modifier changes. No schema, option, or result persists
across reloads unless your own code stores it.

Unknown-key precedence is schema `:unknown`, then parse `unknown`, then
`"warn"`. Invalid unknown modes raise. `safe_parse` handles validation failures
as results. Malformed schemas, throwing default factories, or logging callbacks
can still raise.

Refinements receive the parsed value: return a truthy non-string for success,
`false`/`nil` for failure, or a string as the failure message. Refinement
exceptions become validation issues. Constraints do not coerce values.
`:min`/`:max` count string bytes or table keys. `:range` is numeric.

Lua tables cannot represent an explicitly present `nil` field. `nullable`
therefore differs from `optional` mainly at explicitly parsed value positions,
not missing object fields. `any()` is still required unless made optional.

## API reference

The [API reference](../docs/api.md) lists every function, method, and value
with its parameters and return values. It is generated from the LuaLS
annotations in `plugin/`, so it matches the code. It has these sections:

- [warden](../docs/api.md#warden)
- [warden.assert](../docs/api.md#wardenassert)
- [Warden.Assert.Cmp](../docs/api.md#wardenassertcmp)
- [Warden.Assert.Nul](../docs/api.md#wardenassertnul)
- [Warden.Assert.Num](../docs/api.md#wardenassertnum)
- [Warden.Assert.Str](../docs/api.md#wardenassertstr)
- [Warden.Assert.Tbl](../docs/api.md#wardenasserttbl)
- [Warden.Assert.Type](../docs/api.md#wardenasserttype)
- [Warden.Schema](../docs/api.md#wardenschema)
- [Warden.Result](../docs/api.md#wardenresult)
- [Types](../docs/api.md#types)

`?` marks optional arguments or nullable results. `Schema` below means
`Warden.Schema`. `Result` means `Warden.Result`. Underscore helpers are internal.

### Results

Results contain `{ ok, value, issues, warnings }`. Each issue has `code`,
`path` (key array), `path_text`, `message`, `expected`, `received`, `severity`,
and optional `description`/`details`. Union failures retain one flat
`invalid_union` issue with branch reports in `details.branches`.

### Assertion helpers

The schema API is preferable for configuration. For direct assertions, create
`local a = warden.assert.new { accumulate = true }`. Every group assertion below
also accepts an optional final custom message.

Default assertion failures raise immediately. Table, number, and string group
methods support chaining rather than returning boolean results. Error and stats
getters expose live references. Logging callbacks use dot-style calls in both
APIs. Wrap colon-style logger methods rather than passing them unbound.

## Troubleshooting

### `ok` is true but logs contain a warning

Unknown keys warn by default. Use `unknown = "error"` when a typo must fail,
or `"strip"` when the output must contain only declared fields.

### A nested default is absent

Give the parent object `:default {}` so Warden can descend into it when the
whole object is omitted. `optional()` alone does not create a child object.

Update plugins with `wezterm.plugin.update_all()` from the debug overlay,
then reload. Report [issues](https://github.com/sravioli/warden.wz/issues)
with the schema, sanitized input, plugin revision, and `result:format()` output.

## Development

### Local checkout

Load the working tree directly, so edits take effect on the next config
reload without a commit or a plugin update. Adjust the path to your clone:

```lua
local wezterm = require "wezterm"
local root = wezterm.home_dir .. "/path/to/warden.wz/plugin/"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local warden = require "warden.api"
```

### Editor support

The [wezterm-types collection](https://github.com/DrKJeff16/wezterm-types)
has no Warden definition. Add this checkout's `plugin` directory to
[LuaLS's library](https://luals.github.io/wiki/settings/#workspacelibrary)
to use its local declarations:

```lua
---@type Warden
local warden = wezterm.plugin.require "https://github.com/sravioli/warden.wz"
```

This annotation needs the local definitions. There is no published integration.
See [schema.lua](../plugin/warden/schema.lua) and
[result.lua](../plugin/warden/result.lua).

### Tests and contributions

From the repository root, with Lua 5.4 and the named tools installed:

```sh
busted --verbose
luacheck plugin spec
selene --display-style=quiet plugin
stylua --check plugin spec
```

Specs use a WezTerm mock. Follow the [contribution guide](contributing.md):
keep validation non-mutating, defaults schema-owned, and changes covered by
focused specs. Use Conventional Commits.

## License

Code: [GNU GPL v2](../LICENSE). Documentation:
[CC BY-NC 4.0](../LICENSE-DOCS). Preserve existing attribution.
