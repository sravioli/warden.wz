---@module "warden.result"

local logger = require "warden.logger"

local M = {}
M.__index = M

---@class Warden.Result
---@field ok boolean Whether validation passed without errors.
---@field value any Parsed value with defaults applied.
---@field issues Warden.Issue[] Validation errors.
---@field warnings Warden.Issue[] Non-fatal validation warnings.
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

local function format_issue(prefix, issue)
  return string.format("%s[%s] %s", prefix, issue.path_text, issue.message)
end

local function append_union_branch_lines(lines, issue)
  local details = issue.details
  local branches = details and details.branches

  if not branches then
    return
  end

  for i = 1, #branches do
    local branch = branches[i]
    local branch_issues = branch.issues or {}

    for j = 1, #branch_issues do
      lines[#lines + 1] = format_issue(
        string.format("  - option %s: ", tostring(branch.index or i)),
        branch_issues[j]
      )
    end

    if #branch_issues == 0 then
      local branch_warnings = branch.warnings or {}
      for j = 1, #branch_warnings do
        lines[#lines + 1] = format_issue(
          string.format("  - option %s warning: ", tostring(branch.index or i)),
          branch_warnings[j]
        )
      end
    end
  end
end

---@return string
function M:format()
  local lines = { self:summary() }

  for i = 1, #self.issues do
    local issue = self.issues[i]
    lines[#lines + 1] = string.format("- [%s] %s", issue.path_text, issue.message)
    append_union_branch_lines(lines, issue)
  end

  for i = 1, #self.warnings do
    local warning = self.warnings[i]
    lines[#lines + 1] = string.format("- [warning:%s] %s", warning.path_text, warning.message)
  end

  return table.concat(lines, "\n")
end

local function is_detailed_log(target)
  return type(target) == "table" and target.detailed == true
end

local function log_detailed(self, target)
  if #self.issues > 0 then
    logger.emit("error", self:format(), target)
  elseif #self.warnings > 0 then
    logger.emit("warn", self:format(), target)
  end
end

---@param target? table
---@return Warden.Result self
function M:log(target)
  if is_detailed_log(target) then
    log_detailed(self, target)
    return self
  end

  for i = 1, #self.issues do
    logger.emit(
      "error",
      string.format("[Warden] %s: %s", self.issues[i].path_text, self.issues[i].message),
      target
    )
  end

  for i = 1, #self.warnings do
    logger.emit(
      "warn",
      string.format("[Warden] %s: %s", self.warnings[i].path_text, self.warnings[i].message),
      target
    )
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
