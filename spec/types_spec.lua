local warden = require "warden.api"

describe("warden types", function()
  it("rejects values of the wrong kind with an invalid_type issue", function()
    local cases = {
      array = warden.array(warden.number()),
      tuple = warden.tuple { warden.number() },
      map = warden.map(warden.string(), warden.number()),
      object = warden.object {},
    }
    for kind, schema in pairs(cases) do
      local result = schema:safe_parse(1)
      assert.is_false(result.ok, kind)
      assert.are.equal("invalid_type", result.issues[1].code, kind)
    end
  end)

  it("lists the allowed values of an enum", function()
    local result = warden.enum({ "a", 2 }):safe_parse "c"
    assert.are.equal("invalid_enum_value", result.issues[1].code)
    assert.are.equal("Expected one of: a, 2", result.issues[1].message)
  end)

  it("keeps the warnings of the union branch that matched", function()
    local schema = warden.union {
      warden.object({}):unknown "warn",
      warden.string(),
    }
    local result = schema:safe_parse { extra = 1 }
    assert.is_true(result.ok)
    assert.are.equal("unknown_key", result.warnings[1].code)
  end)
end)
