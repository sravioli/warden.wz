local warden = require "warden.api"

describe("warden.compile", function()
  it("passes a schema through and rejects non-tables and unknown types", function()
    local schema = warden.string()
    assert.are.equal(schema, warden.compile(schema))
    assert.has_error(function()
      warden.compile "string"
    end)
    assert.has_error(function()
      warden.compile { type = "nope" }
    end)
  end)

  it("compiles the primitive and literal kinds", function()
    assert.is_true(warden.compile({ type = "any" }):safe_parse({}).ok)
    assert.is_true(warden.compile({ type = "boolean" }):safe_parse(true).ok)
    assert.is_false(warden.compile({ type = "boolean" }):safe_parse(1).ok)
    assert.is_true(warden.compile({ type = "table" }):safe_parse({}).ok)
    assert.is_false(warden.compile({ type = "table" }):safe_parse(1).ok)
    assert.is_true(warden.compile({ literal = "a" }):safe_parse("a").ok)
    assert.is_false(warden.compile({ literal = "a" }):safe_parse("b").ok)
    assert.is_true(warden.compile({ enum = { "a", "b" } }):safe_parse("b").ok)
  end)

  it("compiles unions, arrays and objects", function()
    local union = warden.compile { union = { { type = "string" }, { type = "number" } } }
    assert.is_true(union:safe_parse(1).ok)
    assert.is_false(union:safe_parse(true).ok)

    local array = warden.compile { type = "array" } -- items default to any
    assert.is_true(array:safe_parse({ 1, "a" }).ok)

    local object = warden.compile { type = "object" }
    assert.is_true(object:safe_parse({}).ok)
  end)

  it("applies the modifiers of a spec", function()
    local opt = warden.compile { type = "string", optional = true }
    assert.is_true(opt:safe_parse(nil).ok)

    local req = warden.compile { type = "string", optional = true, required = true }
    assert.is_false(req:safe_parse(nil).ok)

    local nullable = warden.compile { type = "string", nullable = true }
    assert.is_true(nullable:safe_parse(nil).ok)

    local default = warden.compile { type = "number", default = 3 }
    assert.are.equal(3, default:safe_parse(nil).value)

    local described = warden.compile { type = "string", description = "the name" }
    assert.are.equal("the name", described:safe_parse(1).issues[1].description)

    local ranged = warden.compile { type = "number", min = 1, max = 3 }
    assert.is_true(ranged:safe_parse(2).ok)
    assert.is_false(ranged:safe_parse(5).ok)
    assert.is_false(warden.compile({ type = "number", min = 2 }):safe_parse(1).ok)
    assert.is_false(warden.compile({ type = "number", max = 2 }):safe_parse(3).ok)

    local pattern = warden.compile { type = "string", pattern = "^a" }
    assert.is_false(pattern:safe_parse("b").ok)

    assert.is_false(warden.compile({ type = "string", not_empty = true }):safe_parse("").ok)

    local refined = warden.compile {
      type = "number",
      refine = function(v)
        return v > 1
      end,
      message = "too small",
    }
    assert.are.equal("too small", refined:safe_parse(0).issues[1].message)

    local strict = warden.compile { type = "object", fields = {}, unknown = "error" }
    assert.is_false(strict:safe_parse({ extra = 1 }).ok)
  end)

  it("compiles the object rules, with and without custom messages", function()
    local rules = warden.compile {
      type = "object",
      fields = {
        a = { type = "number", optional = true },
        b = { type = "number", optional = true },
      },
      at_least_one = { "a", "b" },
      mutually_exclusive = { keys = { "a", "b" }, message = "pick one" },
    }
    assert.is_false(rules:safe_parse({}).ok)
    assert.are.equal("pick one", rules:safe_parse({ a = 1, b = 2 }).issues[1].message)

    local one_of = warden.compile {
      type = "object",
      fields = {
        a = { type = "number", optional = true },
        b = { type = "number", optional = true },
      },
      required_one_of = { "a", "b" },
      exactly_one_of = { "a", "b" },
    }
    assert.is_true(one_of:safe_parse({ a = 1 }).ok)
    assert.is_false(one_of:safe_parse({}).ok)
  end)

  it("compiles when rules given as a list, a single rule or with equals", function()
    local fields = {
      kind = { type = "string" },
      path = { type = "string", optional = true },
    }
    local list = warden.compile {
      type = "object",
      fields = fields,
      when = { { field = "kind", expected = "file", required = { "path" } } },
    }
    assert.is_false(list:safe_parse({ kind = "file" }).ok)
    assert.is_true(list:safe_parse({ kind = "file", path = "x" }).ok)

    local single = warden.compile {
      type = "object",
      fields = fields,
      when = { field = "kind", equals = "dir", forbidden = { "path" } },
    }
    assert.is_false(single:safe_parse({ kind = "dir", path = "x" }).ok)
  end)
end)
