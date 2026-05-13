---@module "warden.schema"

local config = require "warden.config"
local issue = require "warden.issue"
local result = require "warden.result"

local M = {}
M.__index = M

---@class Warden.Context
---@field issues Warden.Issue[]
---@field warnings Warden.Issue[]
---@field options table

---@class Warden.Schema
---@field _kind string
---@field _validator function
---@field _optional boolean
---@field _nullable boolean
---@field _has_default boolean
---@field _default any
---@field _description string?
---@field _checks table[]
---@field _refinements table[]
---@field _unknown string?
local Schema = M

---@param value any
---@param seen table?
---@return any
local function clone(value, seen)
  if type(value) ~= "table" then
    return value
  end

  seen = seen or {}
  if seen[value] then
    return seen[value]
  end

  local copied = {}
  seen[value] = copied

  for key, child in pairs(value) do
    copied[clone(key, seen)] = clone(child, seen)
  end

  return copied
end

---@param ctx Warden.Context
---@param severity "error"|"warning"
---@param spec table
local function add_issue(ctx, severity, spec)
  spec.severity = severity
  local item = issue.new(spec)

  if severity == "warning" then
    ctx.warnings[#ctx.warnings + 1] = item
  else
    ctx.issues[#ctx.issues + 1] = item
  end
end

local function describe_new(items, start, description)
  if not description then
    return
  end

  for i = start + 1, #items do
    if not items[i].description then
      items[i].description = description
    end
  end
end

---@param default any
---@return any
local function resolve_default(default)
  if type(default) == "function" then
    return default()
  end

  return clone(default)
end

---@param value any
---@return any
local function measurable(value)
  if type(value) == "string" or type(value) == "table" then
    return #value
  end

  return value
end

---@param kind string
---@param validator function
---@return Warden.Schema
function M.new(kind, validator)
  return setmetatable({
    _kind = kind,
    _validator = validator,
    _optional = false,
    _nullable = false,
    _has_default = false,
    _default = nil,
    _description = nil,
    _checks = {},
    _refinements = {},
  }, Schema)
end

---@return Warden.Schema self
function M:optional()
  self._optional = true
  return self
end

---@return Warden.Schema self
function M:required()
  self._optional = false
  return self
end

---@return Warden.Schema self
function M:nullable()
  self._nullable = true
  return self
end

---@param value any
---@return Warden.Schema self
function M:default(value)
  self._default = value
  self._has_default = true
  return self
end

---@param text string
---@return Warden.Schema self
function M:describe(text)
  self._description = text
  return self
end

---@param mode "keep"|"warn"|"error"|"strip"
---@return Warden.Schema self
function M:unknown(mode)
  self._unknown = mode
  return self
end

---@param fn function
---@param message_or_opts? string|table
---@return Warden.Schema self
function M:refine(fn, message_or_opts)
  local refinement = { fn = fn }

  if type(message_or_opts) == "table" then
    refinement.message = message_or_opts.message
    refinement.code = message_or_opts.code
  else
    refinement.message = message_or_opts
  end

  self._refinements[#self._refinements + 1] = refinement
  return self
end

---@param code string
---@param fn function
---@param message string
---@param expected any
---@return Warden.Schema self
function M:_check(code, fn, message, expected)
  self._checks[#self._checks + 1] = {
    code = code,
    fn = fn,
    message = message,
    expected = expected,
  }

  return self
end

---@param min number
---@return Warden.Schema self
function M:min(min)
  return self:_check("too_small", function(value)
    return measurable(value) >= min
  end, string.format("Expected value >= %s", tostring(min)), ">=" .. tostring(min))
end

---@param max number
---@return Warden.Schema self
function M:max(max)
  return self:_check("too_big", function(value)
    return measurable(value) <= max
  end, string.format("Expected value <= %s", tostring(max)), "<=" .. tostring(max))
end

---@param min number
---@param max number
---@return Warden.Schema self
function M:range(min, max)
  return self:_check(
    "out_of_range",
    function(value)
      return value >= min and value <= max
    end,
    string.format("Expected value between %s and %s", tostring(min), tostring(max)),
    {
      min = min,
      max = max,
    }
  )
end

---@param pattern string
---@return Warden.Schema self
function M:matches(pattern)
  return self:_check("invalid_pattern", function(value)
    return string.match(value, pattern) ~= nil
  end, string.format("Expected string to match pattern %s", pattern), pattern)
end

---@return Warden.Schema self
function M:not_empty()
  return self:_check("empty", function(value)
    return #value > 0
  end, "Expected value to be non-empty", "non-empty")
end

---@param ctx Warden.Context
---@param path any[]
---@param parsed any
---@param start_issues number
local function run_checks(self, ctx, path, parsed, start_issues)
  if #ctx.issues > start_issues then
    return
  end

  for i = 1, #self._checks do
    local check = self._checks[i]
    local ok, passed = pcall(check.fn, parsed)

    if not ok or not passed then
      add_issue(ctx, "error", {
        code = check.code,
        path = path,
        message = check.message,
        expected = check.expected,
        received = parsed,
      })
    end
  end

  if #ctx.issues > start_issues then
    return
  end

  for i = 1, #self._refinements do
    local refinement = self._refinements[i]
    local ok, passed_or_message = pcall(refinement.fn, parsed)

    if not ok or passed_or_message == false or type(passed_or_message) == "string" then
      add_issue(ctx, "error", {
        code = refinement.code or "custom",
        path = path,
        message = type(passed_or_message) == "string" and passed_or_message
          or refinement.message
          or "Value failed custom validation",
        expected = "custom refinement",
        received = parsed,
      })
    end
  end
end

---@param value any
---@param ctx Warden.Context
---@param path any[]
---@param present boolean
---@return any normalized
---@return boolean include
function M:_parse(value, ctx, path, present)
  if not present or value == nil then
    if self._has_default then
      value = resolve_default(self._default)
    elseif self._optional then
      return nil, false
    elseif self._nullable and value == nil and present then
      return nil, true
    else
      add_issue(ctx, "error", {
        code = "required",
        path = path,
        message = "Required value is missing",
        expected = self._kind,
        received = nil,
        description = self._description,
      })

      return nil, false
    end
  end

  local start_issues = #ctx.issues
  local start_warnings = #ctx.warnings
  local parsed = self._validator(self, value, ctx, path)
  run_checks(self, ctx, path, parsed, start_issues)
  describe_new(ctx.issues, start_issues, self._description)
  describe_new(ctx.warnings, start_warnings, self._description)

  return parsed, #ctx.issues == start_issues
end

---@param value any
---@param options? table
---@return Warden.Result
function M:safe_parse(value, options)
  local ctx = {
    issues = {},
    warnings = {},
    options = options or {},
  }

  local parsed = self:_parse(value, ctx, {}, true)
  return result.new(#ctx.issues == 0, parsed, ctx.issues, ctx.warnings)
end

---@param value any
---@param options? table
---@return Warden.Result
function M:validate(value, options)
  return self:safe_parse(value, options)
end

---@param value any
---@param options? table
---@return any
function M:parse(value, options)
  local parsed = self:safe_parse(value, options)
  parsed:throw()
  return parsed.value
end

M._add_issue = add_issue
M._clone = clone
M._config = config

return M
