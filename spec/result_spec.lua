local issue = require "warden.issue"
local result = require "warden.result"
local warden = require "warden.api"

describe("warden results", function()
  it("summarizes a clean result and does not throw", function()
    local parsed = warden.string():safe_parse "a"
    assert.are.equal("Warden validation passed", parsed:summary())
    assert.is_nil(parsed:throw())
  end)

  it("formats the warnings of union branches that raised none", function()
    local failed = issue.new {
      code = "invalid_union",
      path = { "x" },
      message = "no match",
      details = {
        branches = {
          {
            index = 2,
            issues = {},
            warnings = { issue.new { path = { "y" }, message = "careful" } },
          },
          { issues = {} }, -- no warnings either: nothing to print
        },
      },
    }
    local text = result.new(false, nil, { failed }):format()
    assert.matches("option 2 warning: %[y%] careful", text)
  end)

  it("clones a missing path as an empty one", function()
    assert.are.same({}, issue.clone_path(nil))
  end)
end)
