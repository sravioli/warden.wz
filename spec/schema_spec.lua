local warden = require "warden.api"

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
      marker = "wezterm",
      labels = { "a", "b" },
      id = 2,
      even = 4,
    }

    assert.is_true(result.ok)
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
    assert.are.equal(2, #messages)
  end)
end)
