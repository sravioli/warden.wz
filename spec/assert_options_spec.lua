local warden = require "warden.api"

local function new(config)
  config = config or {}
  if config.accumulate == nil then
    config.accumulate = true
  end
  return warden.assert.new(config)
end

describe("warden.assert options", function()
  it("formats messages with a prefix, a context, a group and a length cap", function()
    local a = new { prefix = "p: ", context = "ctx", group_errors = true }
    a.cmp:equal(1, 2, "boom")
    assert.are.equal("[cmp] ctx p: boom", a:get_errors()[1].message)

    local listed = new { context = { "a", "b" } }
    listed.cmp:equal(1, 2, "boom")
    assert.are.equal("[a, b] boom", listed:get_errors()[1].message)

    local capped = new { max_message_length = 4 }
    capped.cmp:equal(1, 2, "too long a message")
    assert.are.equal("too ...", capped:get_errors()[1].message)

    local traced = new { show_stack_trace = true }
    traced.cmp:equal(1, 2, "boom")
    assert.matches("^boom\n", traced:get_errors()[1].message)
  end)

  it("counts every assertion by group and reports to a metrics callback", function()
    local events = {}
    local a = new {
      metrics = {
        record = function(event)
          events[#events + 1] = event
        end,
      },
    }
    a.cmp:equal(1, 1)
    a.cmp:equal(1, 2)
    a.str:not_empty "x"

    local stats = a:get_stats()
    assert.are.same({ total = 3, passed = 2, failed = 1 }, {
      total = stats.total,
      passed = stats.passed,
      failed = stats.failed,
    })
    assert.are.same({ passed = 1, failed = 1 }, stats.by_group.cmp)
    assert.are.same({ passed = 1, failed = 0 }, stats.by_group.str)
    assert.are.same({ "assertion_passed", "assertion_failed", "assertion_passed" }, events)
    assert.is_nil(new():get_stats())
  end)

  it("stops checking after the first failure when lazy_eval is on", function()
    local a = new { lazy_eval = true, metrics = {} }
    assert.is_false(a.cmp:equal(1, 2))
    assert.is_false(a.cmp:equal(1, 3))
    assert.are.equal(1, a:count())
    assert.are.equal(1, a:get_stats().total)

    a:clear()
    assert.is_true(a.cmp:equal(1, 1))
    assert.are.equal(0, a:count())
  end)

  it("calls on_error, format_error and the logger for each failure", function()
    local seen, logged = {}, {}
    local a = new {
      on_error = function(err)
        seen[#seen + 1] = err.message
      end,
      format_error = {
        format = function(err)
          return "formatted " .. err.message
        end,
      },
      logger = {
        error = function(message)
          logged[#logged + 1] = message
        end,
      },
    }
    a.cmp:equal(1, 2, "bad")

    assert.are.same({ "formatted bad" }, seen)
    assert.are.same({ "formatted bad" }, logged)
    assert.are.equal("formatted bad", a:get_errors()[1].message)
  end)

  it("raises in strict mode and through the default handler", function()
    local strict = new { strict_mode = true }
    assert.has_error(function()
      strict.cmp:equal(1, 2, "strict")
    end)

    local plain = new { accumulate = false }
    assert.has_error(function()
      plain.cmp:equal(1, 2, "plain")
    end)
  end)

  it("hands failures to a custom handler", function()
    local handled = {}
    local a = new {
      accumulate = false,
      handler = {
        handle = function(message, level)
          handled[#handled + 1] = { message, level }
        end,
      },
    }
    a.cmp:equal(1, 2, "custom")
    assert.are.equal("custom", handled[1][1])
  end)

  it("keeps errors in silent mode without raising", function()
    local a = new { silent = true, accumulate = false }
    assert.is_false(a.cmp:equal(1, 2))
    assert.are.equal(1, a:count())
  end)

  it("throws accumulated errors once, and fail_fast throws at the first", function()
    local a = new()
    a:throw() -- nothing to throw
    a.cmp:equal(1, 2, "one")
    a.cmp:equal(1, 3, "two")
    local ok, err = pcall(a.throw, a)
    assert.is_false(ok)
    assert.matches("one\ntwo", err)
    assert.are.equal(0, a:count())

    local fast = new { fail_fast = true }
    assert.has_error(function()
      fast.cmp:equal(1, 2, "first")
    end)
  end)
end)

describe("warden.assert checks", function()
  local function failures(run)
    local a = new()
    run(a)
    return a:count()
  end

  it("passes and fails the comparison checks", function()
    assert.are.equal(
      0,
      failures(function(a)
        a.cmp:equal(1, 1)
        a.cmp:not_equal(1, 2)
        a.cmp:truthy(true)
        a.cmp:falsy(false)
      end)
    )
    assert.are.equal(
      4,
      failures(function(a)
        a.cmp:equal(1, 2)
        a.cmp:not_equal(1, 1)
        a.cmp:truthy(false)
        a.cmp:falsy(true)
      end)
    )
  end)

  it("passes and fails the nil and type checks", function()
    assert.are.equal(
      0,
      failures(function(a)
        a.nul:is_nil(nil)
        a.nul:not_nil(1)
        a.type:is_type(1, "number")
      end)
    )
    assert.are.equal(
      3,
      failures(function(a)
        a.nul:is_nil(1)
        a.nul:not_nil(nil)
        a.type:is_type(1, "string")
      end)
    )
  end)

  it("passes and fails the table checks", function()
    assert.are.equal(
      0,
      failures(function(a)
        a.tbl:has_key({ k = 1 }, "k")
        a.tbl:is_empty {}
        a.tbl:not_empty { 1 }
        a.tbl:has_keys({ a = 1, b = 2 }, { "a", "b" })
      end)
    )
    assert.are.equal(
      5,
      failures(function(a)
        a.tbl:has_key({}, "k")
        a.tbl:is_empty { 1 }
        a.tbl:not_empty {}
        a.tbl:has_keys({ a = 1 }, { "a", "b" })
        a.tbl:has_key("not a table", "k")
      end)
    )
  end)

  it("passes and fails the number checks", function()
    assert.are.equal(
      0,
      failures(function(a)
        a.num:in_range(2, 1, 3)
        a.num:greater_than(2, 1)
        a.num:less_than(1, 2)
        a.num:positive(1)
        a.num:negative(-1)
      end)
    )
    assert.are.equal(
      5,
      failures(function(a)
        a.num:in_range(5, 1, 3)
        a.num:greater_than(1, 2)
        a.num:less_than(2, 1)
        a.num:positive(-1)
        a.num:negative(1)
      end)
    )
  end)

  it("passes and fails the string checks", function()
    assert.are.equal(
      0,
      failures(function(a)
        a.str:matches("abc", "^a")
        a.str:starts_with("abc", "ab")
        a.str:ends_with("abc", "bc")
        a.str:contains("abc", "b")
        a.str:not_empty "a"
        a.str:min_length("abc", 3)
        a.str:max_length("abc", 3)
      end)
    )
    assert.are.equal(
      7,
      failures(function(a)
        a.str:matches("abc", "^z")
        a.str:starts_with("abc", "z")
        a.str:ends_with("abc", "z")
        a.str:contains("abc", "z")
        a.str:not_empty ""
        a.str:min_length("a", 3)
        a.str:max_length("abcd", 3)
      end)
    )
  end)

  it("proxies every check group through that()", function()
    local a = new()
    a:that({ 1 }).tbl:not_empty()
    a:that(1).type:is_type "number"
    a:that(1).nul:not_nil()
    a:that(1).cmp:equal(1)
    assert.are.equal(0, a:count())
    assert.is_nil(a:that(1).missing)
  end)
end)
