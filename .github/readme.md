# warden.wz

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/tests.yaml?label=Tests&logo=Lua)](https://github.com/sravioli/warden.wz/actions?workflow=tests)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/warden.wz/lint.yaml?label=Lint&logo=Lua)](https://github.com/sravioli/warden.wz/actions?workflow=lint)
[![Coverage](https://img.shields.io/coverallsCoverage/github/sravioli/warden.wz?label=Coverage&logo=coveralls)](https://coveralls.io/github/sravioli/warden.wz)

Schema validation for [WezTerm](https://wezfurlong.org/wezterm/) plugin and
configuration tables.

Warden lets plugin authors describe configuration once: accepted fields, required
values, defaults, constraints, and readable validation errors all live in the
schema. It validates user input and returns a normalized table without mutating
the original config.

## Installation

```lua
local wezterm = require "wezterm"

local warden = wezterm.plugin.require "https://github.com/sravioli/warden.wz"
```

For local development:

```lua
local wezterm = require "wezterm"

local warden = wezterm.plugin.require(
  "file:///" .. wezterm.config_dir .. "/plugins/warden.wz"
)
```

## Quick Start

```lua
local schema = warden.object {
  window = warden.object {
    opacity = warden.number():range(0, 1):default(0.9),
  }:default {},

  theme = warden.string(),
  title = warden.string():optional(),
}

local result = schema:safe_parse(user_config)

if not result.ok then
  result:log()
end

local config = result.value
```

`config.window.opacity` is present even when the user omits it. `theme` is
required because it has no default and is not marked optional. `title` may be
absent.

## Core Ideas

Warden is not a merge engine. It does not combine a default config table with a
user config table.

Instead, the schema is the default source of truth:

- Fields with `:default(value)` are optional for the user and present in the
  normalized output.
- Fields with `:optional()` are optional and may be absent from the output.
- Fields without `:default()` or `:optional()` are required.
- Unknown object keys warn and remain in the output by default.
- User input is copied into a normalized result and is never mutated.

## Builder API

```lua
local schema = warden.object {
  enabled = warden.boolean():default(true),
  retries = warden.integer():min(0):max(5):default(3),
  level = warden.enum { "debug", "info", "warn", "error" }:default "warn",
  labels = warden.array(warden.string():not_empty()):optional(),
}
```

Constructors:

| Function | Description |
| --- | --- |
| `warden.any()` | Accept any value. |
| `warden.boolean()` | Accept booleans. |
| `warden.string()` | Accept strings. |
| `warden.number()` | Accept numbers. |
| `warden.integer()` | Accept integer numbers. |
| `warden.table()` | Accept tables and copy them. |
| `warden.array(schema)` | Validate dense sequence values. |
| `warden.tuple(schemas)` | Validate fixed positional values. |
| `warden.map(key_schema, value_schema)` | Validate arbitrary keyed tables. |
| `warden.record(value_schema)` | Validate string-keyed tables. |
| `warden.object(fields)` | Validate table fields. |
| `warden.enum(values)` | Accept one value from a list. |
| `warden.literal(value)` | Accept one exact value. |
| `warden.union(schemas)` | Accept the first matching schema. |

Modifiers:

| Method | Description |
| --- | --- |
| `:optional()` | Allow the field to be omitted. |
| `:required()` | Mark the field required explicitly. |
| `:nullable()` | Accept `nil` when the value is explicitly validated. |
| `:default(value_or_fn)` | Use a default when the field is omitted. |
| `:describe(text)` | Attach human-readable context. |
| `:refine(fn, message?)` | Add a custom predicate. |
| `:unknown(mode)` | Set object unknown-key behavior. |
| `:at_least_one(keys, message?)` | Require at least one key. |
| `:required_one_of(keys, message?)` | Alias for `:at_least_one()`. |
| `:mutually_exclusive(keys, message?)` | Allow at most one key. |
| `:exactly_one_of(keys, message?)` | Require exactly one key. |
| `:when(field, value, rules)` | Require or forbid keys conditionally. |

Constraints:

| Method | Description |
| --- | --- |
| `:min(n)` | Minimum numeric value or length. |
| `:max(n)` | Maximum numeric value or length. |
| `:range(min, max)` | Inclusive numeric range. |
| `:matches(pattern)` | Lua pattern match for strings. |
| `:not_empty()` | Require non-empty strings, arrays, or tables. |

## Tables, Records, and Tuples

Use `record()` for plugin option maps with user-defined string keys:

```lua
local palette = warden.record(warden.string():not_empty())
```

Use `map()` when keys need their own schema:

```lua
local bindings = warden.map(warden.integer():min(1), warden.string())
```

`array()` validates dense `1..n` sequences. Sparse arrays and mixed tables are
reported as validation errors. Use `tuple()` for fixed positional values:

```lua
local coordinate = warden.tuple {
  warden.integer(),
  warden.integer(),
}
```

## Object Relationships

Object schemas can describe relationships between fields:

```lua
local action = warden
  .object {
    mode = warden.enum { "builtin", "custom" },
    preset = warden.string():optional(),
    path = warden.string():optional(),
    generated = warden.boolean():optional(),
  }
  :exactly_one_of { "preset", "path" }
  :when("mode", "custom", {
    required = { "path" },
    forbidden = { "generated" },
  })
```

## Declarative Schemas

Schemas can also be declared as tables and compiled:

```lua
local schema = warden.compile {
  type = "object",
  fields = {
    window = {
      type = "object",
      default = {},
      fields = {
        opacity = {
          type = "number",
          min = 0,
          max = 1,
          default = 0.9,
        },
      },
    },
    theme = {
      type = "string",
    },
    palette = {
      type = "record",
      values = {
        type = "string",
        not_empty = true,
      },
    },
    coordinate = {
      type = "tuple",
      items = {
        { type = "integer" },
        { type = "integer" },
      },
    },
  },
  exactly_one_of = { "theme", "palette" },
}
```

Declarative schemas are useful when you want plugin options to stay data-driven.
They compile to the same schema objects used by the builder API.

## Unknown Keys

Object schemas warn and keep unknown keys by default. This catches likely typos
without throwing away user data.

```lua
warden.object(fields):unknown "keep"  -- keep silently
warden.object(fields):unknown "warn"  -- warn and keep, default behavior
warden.object(fields):unknown "error" -- validation error
warden.object(fields):unknown "strip" -- remove from normalized output
```

## Results

Use `safe_parse()` when a plugin should report issues and keep running:

```lua
local result = schema:safe_parse(config)

if result.ok then
  return result.value
end

result:log()
```

Use `parse()` when invalid input should stop immediately:

```lua
local config = schema:parse(user_config)
```

Result helpers:

| Method | Description |
| --- | --- |
| `result:summary()` | Short status line. |
| `result:format()` | Multi-line issue report. |
| `result:log(logger?)` | Log errors and warnings. |
| `result:throw()` | Throw when validation failed. |

Issue objects include:

```lua
{
  code = "out_of_range",
  path = { "window", "opacity" },
  path_text = "window.opacity",
  message = "Expected value between 0 and 1",
  expected = { min = 0, max = 1 },
  received = 1.5,
  severity = "error",
  description = "Window opacity",
  details = nil,
}
```

Union issues keep the top-level `invalid_union` issue flat and include branch
failures in `issue.details.branches`. Descriptions from `:describe()` are copied
onto issues produced by that schema.

`result:format()` expands union details for review while preserving the flat
`result.issues` list:

```text
Warden validation produced 1 error(s)
- [id] Value did not match any union option
  - option 1: [id] Expected string, got number
  - option 2: [id] Expected value >= 1
```

## Assertion Helpers

The previous assertion utility is available as a lower-level helper:

```lua
local assertion = warden.assert.new {
  accumulate = true,
  group_errors = true,
}

assertion.str:not_empty("")
assertion.num:in_range(2, 5, 10)

if assertion:count() > 0 then
  assertion:throw()
end
```

The schema API is the recommended surface for plugin configuration. Assertions
are kept for direct checks and migration paths.

## License

Code is licensed under the [GNU General Public License v2](../LICENSE).
Documentation is licensed under
[Creative Commons Attribution-NonCommercial 4.0 International](../LICENSE-DOCS).
