local warden = require "warden.api"

describe("safe_parse drop_invalid", function()
  local schema = warden.object {
    name = warden.string():default "x",
    style = warden
      .object({
        color = warden.string():not_empty():optional(),
        sep = warden.string():optional(),
      })
      :optional(),
  }

  it("removes only the failing value and keeps its siblings", function()
    local opts = { name = 3, style = { color = "", sep = ">" } }
    local result = schema:safe_parse(opts, { drop_invalid = true })
    assert.is_true(result.ok)
    assert.equal("x", result.value.name)
    assert.same({ sep = ">" }, result.value.style)
    assert.equal(2, #result.dropped)
    assert.is_nil(result.input.name)
    assert.same({ sep = ">" }, result.input.style)
  end)

  it("never changes the input and keeps untouched tables as they are", function()
    local fn_table = { sep = ">" }
    local opts = { name = 3, style = fn_table }
    local result = schema:safe_parse(opts, { drop_invalid = true })
    assert.equal(3, opts.name)
    assert.equal(fn_table, result.input.style)
  end)

  it("reports dropped values when logged and formatted", function()
    local result = schema:safe_parse({ name = 3 }, { drop_invalid = true })
    local lines = {}
    result:log {
      error = function(message)
        lines[#lines + 1] = message
      end,
    }
    assert.equal(1, #lines)
    assert.truthy(lines[1]:find("(ignored)", 1, true))
    assert.truthy(result:format():find("ignored:name", 1, true))
  end)

  it("stays off without the option", function()
    local result = schema:safe_parse { name = 3 }
    assert.is_false(result.ok)
    assert.same({}, result.dropped)
    assert.is_nil(result.input)
  end)
end)
