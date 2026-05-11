local warden = require "warden.api"

describe("warden.assert", function()
  it("keeps accumulated assertion behavior", function()
    local assertion = warden.assert.new {
      accumulate = true,
      group_errors = true,
      metrics = {},
    }

    assertion.cmp:equal("actual", "expected")
    assertion.num:in_range(5, 1, 3)
    assertion.str:not_empty ""

    assert.are.equal(3, assertion:count())
    assert.are.equal(3, assertion:get_stats().failed)
    assert.matches("%[cmp%]", assertion:get_errors()[1].message)
  end)

  it("supports chained value assertions", function()
    local assertion = warden.assert.new {
      accumulate = true,
    }

    assertion:that("hello@example.com").str:not_empty():matches("@"):min_length(5)
    assertion:that(10).num:greater_than(1):less_than(20)

    assert.are.equal(0, assertion:count())
  end)

  it("can throw accumulated errors", function()
    local assertion = warden.assert.new {
      accumulate = true,
    }

    assertion.type:is_type(1, "string")

    assert.has_error(function()
      assertion:throw()
    end)
    assert.are.equal(0, assertion:count())
  end)
end)
