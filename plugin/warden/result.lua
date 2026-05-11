---@module "warden.result"

local logger = require "warden.logger"

local M = {}
M.__index = M

---@class Warden.Result
---@field ok boolean
---@field value any
---@field issues Warden.Issue[]
---@field warnings Warden.Issue[]
local Result = M

---@param ok boolean
---@param value any
---@param issues Warden.Issue[]?
---@param warnings Warden.Issue[]?
---@return Warden.Result
function M.new(ok, value, issues, warnings)
  return setmetatable({
    ok = ok,
    value = value,
    issues = issues or {},
    warnings = warnings or {},
  }, Result)
end

---@return string
function M:summary()
  if self.ok and #self.warnings == 0 then
    return "Warden validation passed"
  end

  local parts = {}

  if #self.issues > 0 then
    parts[#parts + 1] = string.format("%d error(s)", #self.issues)
  end

  if #self.warnings > 0 then
    parts[#parts + 1] = string.format("%d warning(s)", #self.warnings)
  end

  return "Warden validation produced " .. table.concat(parts, " and ")
end

---@return string
function M:format()
  local lines = { self:summary() }

  for i = 1, #self.issues do
    local issue = self.issues[i]
    lines[#lines + 1] = string.format("- [%s] %s", issue.path_text, issue.message)
  end

  for i = 1, #self.warnings do
    local warning = self.warnings[i]
    lines[#lines + 1] = string.format("- [warning:%s] %s", warning.path_text, warning.message)
  end

  return table.concat(lines, "\n")
end

---@param target? table
---@return Warden.Result self
function M:log(target)
  for i = 1, #self.issues do
    logger.emit("error", string.format("[Warden] %s", self.issues[i].message), target)
  end

  for i = 1, #self.warnings do
    logger.emit("warn", string.format("[Warden] %s", self.warnings[i].message), target)
  end

  return self
end

---@return nil
function M:throw()
  if self.ok then
    return
  end

  error(self:format(), 2)
end

return M
