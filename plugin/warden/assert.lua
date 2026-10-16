---@module "warden.assert"

local M = {}
M.__index = M

---@param config? table
---@return table
function M.new(config)
  config = config or {}

  local self = setmetatable({}, M)
  self._errors = {}
  self._config = config
  self._accumulate = config.accumulate or false
  self._fail_fast = config.fail_fast or false
  self._has_failed = false
  self._type_cache = config.cache_type_checks and {} or nil
  self._stats = config.metrics
      and {
        total = 0,
        passed = 0,
        failed = 0,
        by_group = {},
      }
    or nil

  self._handler = config.handler
    or {
      handle = function(message, level)
        error(message, level + 1)
      end,
    }

  self.cmp = setmetatable({ _parent = self, _group = "cmp" }, { __index = M._cmp })
  self.nul = setmetatable({ _parent = self, _group = "nul" }, { __index = M._nul })
  self.type = setmetatable({ _parent = self, _group = "type" }, { __index = M._type })
  self.tbl = setmetatable({ _parent = self, _group = "tbl" }, { __index = M._tbl })
  self.num = setmetatable({ _parent = self, _group = "num" }, { __index = M._num })
  self.str = setmetatable({ _parent = self, _group = "str" }, { __index = M._str })

  return self
end

---@param value any
---@return table
function M:that(value)
  local holder = { value = value, parent = self }

  setmetatable(holder, {
    __index = function(t, key)
      if
        key == "str"
        or key == "num"
        or key == "tbl"
        or key == "type"
        or key == "nul"
        or key == "cmp"
      then
        local proxy = setmetatable({ _value = value, _parent = self, _group = key }, {
          __index = function(p, method)
            return function(_, ...)
              M["_" .. key][method](p, p._value, ...)
              return p
            end
          end,
        })
        rawset(t, key, proxy)
        return proxy
      end
      return rawget(t, key)
    end,
  })

  return holder
end

---@param message string
---@param group? string
---@return string
function M:_format_message(message, group)
  local config = self._config
  local formatted = message

  if config.prefix then
    formatted = config.prefix .. formatted
  end

  if config.context then
    local ctx = type(config.context) == "string" and config.context
      or string.format("[%s]", table.concat(config.context, ", "))
    formatted = ctx .. " " .. formatted
  end

  if config.group_errors and group then
    formatted = string.format("[%s] %s", group, formatted)
  end

  if config.show_stack_trace then
    formatted = formatted .. "\n" .. debug.traceback("", 4)
  end

  if config.max_message_length and #formatted > config.max_message_length then
    formatted = formatted:sub(1, config.max_message_length) .. "..."
  end

  return formatted
end

---@param passed boolean
---@param group? string
function M:_update_metrics(passed, group)
  if not self._stats then
    return
  end

  self._stats.total = self._stats.total + 1

  if passed then
    self._stats.passed = self._stats.passed + 1
  else
    self._stats.failed = self._stats.failed + 1
  end

  if group then
    self._stats.by_group[group] = self._stats.by_group[group] or { passed = 0, failed = 0 }
    if passed then
      self._stats.by_group[group].passed = self._stats.by_group[group].passed + 1
    else
      self._stats.by_group[group].failed = self._stats.by_group[group].failed + 1
    end
  end

  if self._config.metrics and self._config.metrics.record then
    self._config.metrics.record(passed and "assertion_passed" or "assertion_failed")
  end
end

---@param condition boolean
---@param message string
---@param level? number
---@param group? string
---@return boolean
function M:_check(condition, message, level, group)
  level = level or 2

  if self._config.lazy_eval and self._has_failed then
    return condition
  end

  self:_update_metrics(condition, group)

  if not condition then
    self._has_failed = true

    local err = {
      message = self:_format_message(message, group),
      level = level,
      group = group,
      timestamp = os.time(),
    }

    if self._config.format_error then
      err.message = self._config.format_error.format(err, self._config)
    end

    if self._config.on_error then
      self._config.on_error(err)
    end

    if self._config.logger and self._config.logger.error then
      self._config.logger.error(err.message)
    end

    if self._config.silent then
      self._errors[#self._errors + 1] = err
      return condition
    end

    if self._config.strict_mode then
      error(err.message, level + 1)
    end

    if self._accumulate then
      self._errors[#self._errors + 1] = err
      if self._fail_fast then
        self:throw()
      end
    else
      self._handler.handle(err.message, level)
    end
  end

  return condition
end

---@param value any
---@return string
function M:_get_type(value)
  if not self._type_cache then
    return type(value)
  end

  local value_type = type(value)
  if not self._type_cache[value_type] then
    self._type_cache[value_type] = value_type
  end

  return self._type_cache[value_type]
end

function M:throw()
  if #self._errors == 0 then
    return
  end

  local messages = {}
  for i = 1, #self._errors do
    messages[i] = self._errors[i].message
  end

  self._errors = {}
  self._handler.handle(table.concat(messages, "\n"), 2)
end

function M:clear()
  self._errors = {}
  self._has_failed = false
end

---@return number
function M:count()
  return #self._errors
end

---@return table[]
function M:get_errors()
  return self._errors
end

---@return table?
function M:get_stats()
  return self._stats
end

M._cmp = {}

function M._cmp:equal(actual, expected, message)
  message = message or string.format("Expected %s, got: %s", tostring(expected), tostring(actual))
  return self._parent:_check(actual == expected, message, 3, self._group)
end

function M._cmp:not_equal(actual, expected, message)
  message = message or string.format("Expected value different from: %s", tostring(expected))
  return self._parent:_check(actual ~= expected, message, 3, self._group)
end

function M._cmp:truthy(value, message)
  message = message or string.format("Expected truthy value, got: %s", tostring(value))
  return self._parent:_check(not not value, message, 3, self._group)
end

function M._cmp:falsy(value, message)
  message = message or string.format("Expected falsy value, got: %s", tostring(value))
  return self._parent:_check(not value, message, 3, self._group)
end

M._nul = {}

function M._nul:is_nil(value, message)
  message = message or string.format("Expected nil, got: %s", tostring(value))
  return self._parent:_check(value == nil, message, 3, self._group)
end

function M._nul:not_nil(value, message)
  message = message or "Expected non-nil value"
  return self._parent:_check(value ~= nil, message, 3, self._group)
end

M._type = {}

function M._type:is_type(value, expected_type, message)
  local actual_type = self._parent:_get_type(value)
  message = message or string.format("Expected type %s, got: %s", expected_type, actual_type)
  return self._parent:_check(actual_type == expected_type, message, 3, self._group)
end

M._tbl = {}

function M._tbl:has_key(tbl, key, message)
  message = message or string.format("Table missing key: %s", tostring(key))
  self._parent:_check(type(tbl) == "table" and tbl[key] ~= nil, message, 3, self._group)
  return self
end

function M._tbl:is_empty(tbl, message)
  message = message or "Expected empty table"
  self._parent:_check(type(tbl) == "table" and next(tbl) == nil, message, 3, self._group)
  return self
end

function M._tbl:not_empty(tbl, message)
  message = message or "Expected non-empty table"
  self._parent:_check(type(tbl) == "table" and next(tbl) ~= nil, message, 3, self._group)
  return self
end

function M._tbl:has_keys(tbl, keys, message)
  for _, key in ipairs(keys) do
    local msg = message or string.format("Table missing key: %s", tostring(key))
    self._parent:_check(type(tbl) == "table" and tbl[key] ~= nil, msg, 3, self._group)
  end
  return self
end

M._num = {}

function M._num:in_range(value, min, max, message)
  message = message or string.format("Expected value in range [%s, %s], got: %s", min, max, value)
  self._parent:_check(
    type(value) == "number" and value >= min and value <= max,
    message,
    3,
    self._group
  )
  return self
end

function M._num:greater_than(value, threshold, message)
  message = message or string.format("Expected value > %s, got: %s", threshold, value)
  self._parent:_check(type(value) == "number" and value > threshold, message, 3, self._group)
  return self
end

function M._num:less_than(value, threshold, message)
  message = message or string.format("Expected value < %s, got: %s", threshold, value)
  self._parent:_check(type(value) == "number" and value < threshold, message, 3, self._group)
  return self
end

function M._num:positive(value, message)
  message = message or string.format("Expected positive number, got: %s", value)
  self._parent:_check(type(value) == "number" and value > 0, message, 3, self._group)
  return self
end

function M._num:negative(value, message)
  message = message or string.format("Expected negative number, got: %s", value)
  self._parent:_check(type(value) == "number" and value < 0, message, 3, self._group)
  return self
end

M._str = {}

function M._str:matches(str, pattern, message)
  message = message
    or string.format("String '%s' does not match pattern '%s'", tostring(str), pattern)
  self._parent:_check(
    type(str) == "string" and string.match(str, pattern) ~= nil,
    message,
    3,
    self._group
  )
  return self
end

function M._str:starts_with(str, prefix, message)
  message = message or string.format("String '%s' does not start with '%s'", tostring(str), prefix)
  self._parent:_check(
    type(str) == "string" and str:sub(1, #prefix) == prefix,
    message,
    3,
    self._group
  )
  return self
end

function M._str:ends_with(str, suffix, message)
  message = message or string.format("String '%s' does not end with '%s'", tostring(str), suffix)
  self._parent:_check(
    type(str) == "string" and (suffix == "" or str:sub(-#suffix) == suffix),
    message,
    3,
    self._group
  )
  return self
end

function M._str:contains(str, substring, message)
  message = message or string.format("String '%s' does not contain '%s'", tostring(str), substring)
  self._parent:_check(
    type(str) == "string" and str:find(substring, 1, true) ~= nil,
    message,
    3,
    self._group
  )
  return self
end

function M._str:not_empty(str, message)
  message = message or "String cannot be empty"
  self._parent:_check(type(str) == "string" and str ~= "", message, 3, self._group)
  return self
end

function M._str:min_length(str, len, message)
  message = message or string.format("String must be at least %d characters", len)
  self._parent:_check(type(str) == "string" and #str >= len, message, 3, self._group)
  return self
end

function M._str:max_length(str, len, message)
  message = message or string.format("String must be at most %d characters", len)
  self._parent:_check(type(str) == "string" and #str <= len, message, 3, self._group)
  return self
end

return M
