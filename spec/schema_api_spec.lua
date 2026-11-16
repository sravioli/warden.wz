local warden = require "warden.api"

describe("warden schema api", function()
  it("keeps cyclic defaults cyclic when cloning them", function()
    local cyclic = {}
    cyclic.me = cyclic
    local parsed = warden.object({ x = warden.any():default(cyclic) }):parse {}
    assert.are_not.equal(cyclic, parsed.x)
    assert.are.equal(parsed.x, parsed.x.me)
  end)

  it("calls a default given as a function", function()
    assert.are.equal(
      7,
      warden
        .number()
        :default(function()
          return 7
        end)
        :parse(nil)
    )
  end)

  it("accepts a single key for the key rules", function()
    local schema = warden.object({ a = warden.number():optional() }):at_least_one "a"
    assert.is_false(schema:safe_parse({}).ok)
    assert.is_true(schema:safe_parse({ a = 1 }).ok)
  end)

  it("takes a message and a code for a refinement", function()
    local schema = warden.number():refine(function(v)
      return v > 1
    end, { message = "too small", code = "small" })
    local issue = schema:safe_parse(0).issues[1]
    assert.are.equal("too small", issue.message)
    assert.are.equal("small", issue.code)
  end)

  it("validates and parses", function()
    assert.is_true(warden.string():validate("a").ok)
    assert.are.equal("a", warden.string():parse "a")
    assert.has_error(function()
      warden.string():parse(1)
    end)
  end)
end)
