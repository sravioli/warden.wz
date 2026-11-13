# warden.wz

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/tests.yaml?style=flat-square&label=tests)](https://github.com/sravioli/warden.wz/actions/workflows/tests.yaml)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/lint.yaml?style=flat-square&label=lint)](https://github.com/sravioli/warden.wz/actions/workflows/lint.yaml)
[![Coverage](https://img.shields.io/coverallsCoverage/github/sravioli/warden.wz?label=Coverage&logo=coveralls)](https://coveralls.io/github/sravioli/warden.wz)
[![Code license](https://img.shields.io/badge/code-GPL--2.0-blue?style=flat-square)](../LICENSE)
[![Docs license](https://img.shields.io/badge/docs-CC_BY--NC_4.0-blue?style=flat-square)](../LICENSE-DOCS)

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
Warnings do not make `ok` false. Read `result.value` only after checking `ok`;
a failed result can contain partial normalized data.
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

There is no global setup function. Defaults belong to schemas; parse and
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

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `unknown` | `"keep"\|"warn"\|"error"\|"strip"` | `"warn"` | Parse option: keep silently, warn and keep, fail, or remove unknown object keys. A schema's `:unknown` wins. |
| `detailed` | `boolean` | `false` | `result:log` option: emit one expanded report instead of one compact line per issue. |
| `error` | `fun(message: string)` | `nil` | Error callback on the table passed directly to `result:log`; called without `self`. |
| `warn` | `fun(message: string)` | `nil` | Warning callback on the same table; called without `self`. |
| `log_error` | `fun(message: string)` | `nil` | WezTerm-style alternative when `error` is absent. |
| `log_warn` | `fun(message: string)` | `nil` | WezTerm-style alternative when `warn` is absent. |
| `log` | `fun(level: string, message: string)` | `nil` | Generic callback used when the level-specific callbacks are absent. |

#### Assertion construction

Pass these to `warden.assert.new`; they do not configure schemas.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `accumulate` | `boolean` | `false` | Collect failures until `throw` instead of invoking the handler immediately. |
| `fail_fast` | `boolean` | `false` | Throw on the first accumulated failure. |
| `silent` | `boolean` | `false` | Collect failures without invoking the handler; callbacks/logging still run. |
| `strict_mode` | `boolean` | `false` | Raise immediately, before accumulation; `silent` takes precedence. |
| `lazy_eval` | `boolean` | `false` | After a failure, skip further bookkeeping and error handling. |
| `cache_type_checks` | `boolean` | `false` | Cache type-name lookups. |
| `prefix` | `string?` | `nil` | Prefix error messages. |
| `context` | `string\|string[]?` | `nil` | Prepend context to messages. |
| `group_errors` | `boolean` | `false` | Prefix the assertion group name. |
| `show_stack_trace` | `boolean` | `false` | Append a traceback; requires Lua's `debug` library. |
| `max_message_length` | `integer?` | `nil` | Byte limit before appending `"..."`. |
| `handler.handle` | `fun(message: string, level: integer)` | Computed raising handler | Error handler called without `self`; custom handlers may return. |
| `format_error.format` | `fun(error: table, config: table): string` | `nil` | Replace formatted error text; called without `self`. |
| `on_error` | `fun(error: table)` | `nil` | Failure callback before handler/collection. |
| `logger.error` | `fun(message: string)` | `nil` | Assertion diagnostic callback, called without `self`. |
| `metrics.record` | `fun(event: string)` | `nil` | Optional metrics callback; supplying a `metrics` table also enables counters. |

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
as results; malformed schemas, throwing default factories, or logging callbacks
can still raise.

Refinements receive the parsed value: return a truthy non-string for success,
`false`/`nil` for failure, or a string as the failure message. Refinement
exceptions become validation issues. Constraints do not coerce values.
`:min`/`:max` count string bytes or table keys; `:range` is numeric.

Lua tables cannot represent an explicitly present `nil` field. `nullable`
therefore differs from `optional` mainly at explicitly parsed value positions,
not missing object fields. `any()` is still required unless made optional.

## API reference

`?` marks optional arguments or nullable results. `Schema` below means
`Warden.Schema`; `Result` means `Warden.Result`. Underscore helpers are internal.

### Constructors

| Signature → Return type | Description |
| --- | --- |
| `warden.any() → Schema` | Accept and copy any present value. |
| `warden.boolean() → Schema` | Require a boolean. |
| `warden.string() → Schema` | Require a string. |
| `warden.number() → Schema` | Require a Lua number. |
| `warden.integer() → Schema` | Require a number with no fractional part. |
| `warden.table() → Schema` | Require and deep-copy a table. |
| `warden.array(item_schema) → Schema` | Validate a dense positive-integer sequence; reject sparse/mixed keys. |
| `warden.tuple(item_schemas) → Schema` | Validate fixed positions, rejecting missing or extra positions. |
| `warden.map(key_schema, value_schema) → Schema` | Validate keys and values; report duplicate normalized keys. |
| `warden.record(value_schema) → Schema` | String-keyed map. |
| `warden.object(fields) → Schema` | Validate named fields and apply the unknown-key policy. |
| `warden.enum(values) → Schema` | Accept one listed value by Lua equality. |
| `warden.literal(value) → Schema` | Accept one exact value by Lua equality. |
| `warden.union(schemas) → Schema` | Use the first branch without errors; preserve that branch's warnings. |
| `warden.compile(spec) → Schema` | Compile a declarative spec, or return an existing schema unchanged. |

### Schema operations

| Signature → Return type | Description |
| --- | --- |
| `schema:optional() → Schema` | Permit omission. |
| `schema:required() → Schema` | Clear the optional flag; an existing default still applies. |
| `schema:nullable() → Schema` | Permit an explicitly parsed `nil`. |
| `schema:default(value_or_fn) → Schema` | Set a copied value or zero-argument default factory. |
| `schema:describe(text) → Schema` | Attach context to generated issues. |
| `schema:unknown(mode) → Schema` | Set this object's unknown-key policy. |
| `schema:refine(fn, message_or_options?) → Schema` | Add a predicate; options may contain `message` and `code`. |
| `schema:min(n) → Schema` | Inclusive minimum value/byte length/key count. |
| `schema:max(n) → Schema` | Inclusive maximum value/byte length/key count. |
| `schema:range(min, max) → Schema` | Inclusive numeric bounds. |
| `schema:matches(pattern) → Schema` | Match a Lua string pattern, not a regular expression. |
| `schema:not_empty() → Schema` | Require positive length/key count/value. |
| `schema:at_least_one(keys, message?) → Schema` | Require one or more listed fields; alias `required_one_of`. |
| `schema:required_one_of(keys, message?) → Schema` | Alias of `at_least_one`. |
| `schema:mutually_exclusive(keys, message?) → Schema` | Allow at most one listed field. |
| `schema:exactly_one_of(keys, message?) → Schema` | Require exactly one listed field. |
| `schema:when(field, expected, rules) → Schema` | Conditionally require/forbid fields after defaults. |
| `schema:safe_parse(value, options?) → Result` | Return normalized data, errors, and warnings without throwing for validation issues. |
| `schema:validate(value, options?) → Result` | Alias of `safe_parse`. |
| `schema:parse(value, options?) → any` | Return normalized data or raise a formatted validation error. |

### Results

| Signature → Return type | Description |
| --- | --- |
| `result:summary() → string` | Produce a short error/warning count or success line. |
| `result:format() → string` | Format all issues, expanding union branch details. |
| `result:log(logger_or_options?) → Result` | Log issues/warnings and return the same result. |
| `result:throw() → nil` | Raise if `ok` is false; otherwise do nothing. |

Results contain `{ ok, value, issues, warnings }`. Each issue has `code`,
`path` (key array), `path_text`, `message`, `expected`, `received`, `severity`,
and optional `description`/`details`. Union failures retain one flat
`invalid_union` issue with branch reports in `details.branches`.

### Assertion helpers

The schema API is preferable for configuration. For direct checks, create
`local a = warden.assert.new { accumulate = true }`. Every group check below
also accepts an optional final custom message.

| Signature → Return type | Description |
| --- | --- |
| `warden.assert.new(options?) → table` | Create an independent assertion collector. |
| `a:that(value) → table` | Bind a value for fluent checks such as `a:that("x").str:not_empty()`. |
| `a:throw() → nil` | Clear and pass accumulated messages to the handler; the default handler raises. |
| `a:clear() → nil` | Clear errors and the previous-failure flag. |
| `a:count() → integer` | Count collected errors. |
| `a:get_errors() → table[]` | Return the live error list. |
| `a:get_stats() → table?` | Return live counters when `metrics` was configured. |
| `a.cmp:equal(actual, expected, message?) → boolean` | Check Lua equality. |
| `a.cmp:not_equal(actual, expected, message?) → boolean` | Check inequality. |
| `a.cmp:truthy(value, message?) → boolean` | Require a truthy value. |
| `a.cmp:falsy(value, message?) → boolean` | Require `nil` or `false`. |
| `a.nul:is_nil(value, message?) → boolean` | Require `nil`. |
| `a.nul:not_nil(value, message?) → boolean` | Require a non-`nil` value. |
| `a.type:is_type(value, expected_type, message?) → boolean` | Compare Lua type names. |
| `a.tbl:has_key(value, key, message?) → table` | Require a table with a non-`nil` key; return the group. |
| `a.tbl:has_keys(value, keys, message?) → table` | Check each listed key. |
| `a.tbl:is_empty(value, message?) → table` | Require a table with no keys. |
| `a.tbl:not_empty(value, message?) → table` | Require at least one key. |
| `a.num:in_range(value, min, max, message?) → table` | Inclusive numeric range. |
| `a.num:greater_than(value, threshold, message?) → table` | Strict lower bound. |
| `a.num:less_than(value, threshold, message?) → table` | Strict upper bound. |
| `a.num:positive(value, message?) → table` | Require a number greater than zero. |
| `a.num:negative(value, message?) → table` | Require a number less than zero. |
| `a.str:matches(value, pattern, message?) → table` | Match a Lua pattern. |
| `a.str:starts_with(value, prefix, message?) → table` | Literal prefix. |
| `a.str:ends_with(value, suffix, message?) → table` | Literal suffix; empty suffix succeeds. |
| `a.str:contains(value, substring, message?) → table` | Literal substring. |
| `a.str:not_empty(value, message?) → table` | Non-empty string. |
| `a.str:min_length(value, length, message?) → table` | Minimum byte length. |
| `a.str:max_length(value, length, message?) → table` | Maximum byte length. |

Default assertion failures raise immediately. Table, number, and string group
methods support chaining rather than returning boolean results. Error and stats
getters expose live references. Logging callbacks use dot-style calls in both
APIs; wrap colon-style logger methods rather than passing them unbound.

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

Clone into `plugins/warden.wz` beneath `wezterm.config_dir`, then replace
the remote import:

```lua
local wezterm = require "wezterm"
local warden = wezterm.plugin.require(
  "file:///" .. wezterm.config_dir .. "/plugins/warden.wz"
)
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

This annotation needs the local definitions; there is no published integration.
See [schema.lua](../plugin/warden/schema.lua) and
[result.lua](../plugin/warden/result.lua).

### Checks and contributions

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
