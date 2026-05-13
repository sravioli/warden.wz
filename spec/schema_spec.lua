local warden = require "warden.api"

local function has_issue(issues, code)
  for i = 1, #issues do
    if issues[i].code == code then
      return true
    end
  end

  return false
end

describe("warden schemas", function()
  it("applies schema defaults without mutating user config", function()
    local schema = warden.object {
      window = warden
        .object({
          opacity = warden.number():range(0, 1):default(0.9),
        })
        :default {},
      theme = warden.string(),
      title = warden.string():optional(),
    }

    local user = { theme = "kanagawa" }
    local result = schema:safe_parse(user)

    assert.is_true(result.ok)
    assert.are.equal("kanagawa", result.value.theme)
    assert.are.equal(0.9, result.value.window.opacity)
    assert.is_nil(result.value.title)
    assert.is_nil(user.window)
  end)

  it("reports missing required fields", function()
    local schema = warden.object {
      theme = warden.string(),
    }

    local result = schema:safe_parse {}

    assert.is_false(result.ok)
    assert.are.equal(1, #result.issues)
    assert.are.equal("theme", result.issues[1].path_text)
    assert.are.equal("required", result.issues[1].code)
  end)

  it("validates numeric ranges with precise paths", function()
    local schema = warden.object {
      window = warden.object {
        opacity = warden.number():range(0, 1),
      },
    }

    local result = schema:safe_parse {
      window = {
        opacity = 1.5,
      },
    }

    assert.is_false(result.ok)
    assert.are.equal("window.opacity", result.issues[1].path_text)
    assert.are.equal("out_of_range", result.issues[1].code)
  end)

  it("keeps path text unambiguous for keys containing dots", function()
    local schema = warden.object {
      ["window.opacity"] = warden.number(),
    }

    local result = schema:safe_parse {}

    assert.is_false(result.ok)
    assert.are.equal('["window.opacity"]', result.issues[1].path_text)
  end)

  it("warns and keeps unknown keys by default", function()
    local schema = warden.object {
      enabled = warden.boolean():default(true),
    }

    local result = schema:safe_parse {
      extra = "kept",
    }

    assert.is_true(result.ok)
    assert.are.equal(true, result.value.enabled)
    assert.are.equal("kept", result.value.extra)
    assert.are.equal(1, #result.warnings)
    assert.are.equal("extra", result.warnings[1].path_text)
  end)

  it("supports every unknown key policy", function()
    local keep = warden.object({ enabled = warden.boolean():default(true) }):unknown "keep"
    local warn = warden.object({ enabled = warden.boolean():default(true) }):unknown "warn"
    local strip = warden.object({ enabled = warden.boolean():default(true) }):unknown "strip"
    local err = warden.object({ enabled = warden.boolean():default(true) }):unknown "error"

    local input = { extra = "value" }

    assert.are.equal("value", keep:safe_parse(input).value.extra)
    assert.are.equal(0, #keep:safe_parse(input).warnings)
    assert.are.equal("value", warn:safe_parse(input).value.extra)
    assert.are.equal(1, #warn:safe_parse(input).warnings)
    assert.is_nil(strip:safe_parse(input).value.extra)
    assert.is_false(err:safe_parse(input).ok)
  end)

  it("compiles declarative schemas to the same behavior as builder schemas", function()
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
        labels = {
          type = "array",
          items = { type = "string" },
          optional = true,
        },
      },
    }

    local result = schema:safe_parse {}

    assert.is_true(result.ok)
    assert.are.equal(0.9, result.value.window.opacity)
    assert.is_nil(result.value.labels)
  end)

  it("supports enums, literals, arrays, unions, and refinements", function()
    local schema = warden.object {
      level = warden.enum { "info", "warn", "error" },
      retries = warden.enum { 1, 2, 3 },
      marker = warden.literal "wezterm",
      labels = warden.array(warden.string():not_empty()),
      id = warden.union {
        warden.string():not_empty(),
        warden.integer():min(1),
      },
      even = warden.integer():refine(function(value)
        return value % 2 == 0
      end, "Expected an even integer"),
    }

    local result = schema:safe_parse {
      level = "warn",
      retries = 2,
      marker = "wezterm",
      labels = { "a", "b" },
      id = 2,
      even = 4,
    }

    assert.is_true(result.ok)
  end)

  it("adds descriptions and union branch details to issues", function()
    local schema = warden.object {
      id = warden
        .union {
          warden.string():not_empty(),
          warden.integer():min(1),
        }
        :describe "Plugin identifier",
    }

    local result = schema:safe_parse {
      id = false,
    }

    assert.is_false(result.ok)
    assert.are.equal("invalid_union", result.issues[1].code)
    assert.are.equal("Plugin identifier", result.issues[1].description)
    assert.are.equal(2, #result.issues[1].details.branches)
    assert.are.equal(1, result.issues[1].details.branches[1].index)
    assert.are.equal("invalid_type", result.issues[1].details.branches[1].issues[1].code)
  end)

  it("validates string-keyed records", function()
    local schema = warden.record(warden.number():min(1))

    local valid = schema:safe_parse {
      left = 1,
      right = 2,
    }
    local invalid = schema:safe_parse {
      left = 0,
      [1] = 2,
    }

    assert.is_true(valid.ok)
    assert.are.equal(2, valid.value.right)
    assert.is_false(invalid.ok)
    assert.is_true(has_issue(invalid.issues, "too_small"))
    assert.is_true(has_issue(invalid.issues, "invalid_type"))
  end)

  it("validates map keys and values", function()
    local schema = warden.map(warden.number():min(1), warden.string():not_empty())

    local result = schema:safe_parse {
      [1] = "one",
      [2] = "",
      [0] = "zero",
    }

    assert.is_false(result.ok)
    assert.is_true(has_issue(result.issues, "empty"))
    assert.is_true(has_issue(result.issues, "too_small"))
  end)

  it("compiles record and map schemas", function()
    local schema = warden.compile {
      type = "object",
      fields = {
        colors = {
          type = "record",
          values = { type = "string", not_empty = true },
        },
        aliases = {
          type = "map",
          keys = { type = "integer", min = 1 },
          values = { type = "string" },
        },
      },
    }

    local result = schema:safe_parse {
      colors = {
        primary = "#7aa2f7",
      },
      aliases = {
        [1] = "leader",
      },
    }

    assert.is_true(result.ok)
    assert.are.equal("#7aa2f7", result.value.colors.primary)
    assert.are.equal("leader", result.value.aliases[1])
  end)

  it("validates object relationship rules", function()
    local schema = warden
      .object {
        name = warden.string():optional(),
        command = warden.string():optional(),
        url = warden.string():optional(),
        file = warden.string():optional(),
      }
      :at_least_one { "name", "command" }
      :mutually_exclusive { "url", "file" }

    local missing = schema:safe_parse {}
    local conflict = schema:safe_parse {
      name = "open",
      url = "https://example.com",
      file = "local.html",
    }

    assert.is_false(missing.ok)
    assert.are.equal("at_least_one", missing.issues[1].code)
    assert.is_false(conflict.ok)
    assert.are.equal("mutually_exclusive", conflict.issues[1].code)
  end)

  it("validates exactly-one and conditional object rules", function()
    local schema = warden
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

    local result = schema:safe_parse {
      mode = "custom",
      preset = "default",
      generated = true,
    }

    assert.is_false(result.ok)
    assert.is_true(has_issue(result.issues, "conditional_required"))
    assert.is_true(has_issue(result.issues, "conditional_forbidden"))
  end)

  it("compiles object relationship rules", function()
    local schema = warden.compile {
      type = "object",
      fields = {
        mode = { enum = { "builtin", "custom" } },
        preset = { type = "string", optional = true },
        path = { type = "string", optional = true },
      },
      required_one_of = { "preset", "path" },
      when = {
        field = "mode",
        expected = "custom",
        required = { "path" },
      },
    }

    local result = schema:safe_parse {
      mode = "custom",
    }

    assert.is_false(result.ok)
    assert.is_true(has_issue(result.issues, "at_least_one"))
    assert.is_true(has_issue(result.issues, "conditional_required"))
  end)

  it("does not throw from safe_parse and does throw from parse", function()
    local schema = warden.object {
      opacity = warden.number():range(0, 1),
    }

    local result = schema:safe_parse {
      opacity = 2,
    }

    assert.is_false(result.ok)
    assert.has_error(function()
      schema:parse {
        opacity = 2,
      }
    end)
  end)

  it("formats and logs validation results without depending on log.wz", function()
    local messages = {}
    local schema = warden.object {
      opacity = warden.number():range(0, 1),
    }

    local result = schema:safe_parse {
      opacity = 2,
      unexpected = true,
    }

    result:log {
      error = function(message)
        messages[#messages + 1] = message
      end,
      warn = function(message)
        messages[#messages + 1] = message
      end,
    }

    assert.matches("Warden validation produced", result:summary(), 1, true)
    assert.matches("opacity", result:format(), 1, true)
    assert.matches("opacity", messages[1], 1, true)
    assert.are.equal(2, #messages)
  end)
end)
