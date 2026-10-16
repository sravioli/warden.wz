---@module "warden.types"

local issue = require "warden.issue"
local schema = require "warden.schema"

local M = {}

---@param ctx Warden.Context
---@param path any[]
---@param code string
---@param expected any
---@param received any
local function invalid_type(ctx, path, code, expected, received)
  schema._add_issue(ctx, "error", {
    code = code or "invalid_type",
    path = path,
    message = string.format("Expected %s, got %s", tostring(expected), type(received)),
    expected = expected,
    received = type(received),
  })
end

---@param values any[]
---@return string
local function join_values(values)
  local parts = {}

  for i = 1, #values do
    parts[i] = tostring(values[i])
  end

  return table.concat(parts, ", ")
end

local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function add_invalid_array_key(ctx, path, key)
  schema._add_issue(ctx, "error", {
    code = "invalid_array_key",
    path = issue.child_path(path, key),
    message = "Array keys must be positive integers",
    expected = "positive integer key",
    received = key,
  })
end

local function validate_dense_array(ctx, path, value)
  local indexes = {}

  for key in pairs(value) do
    if is_positive_integer(key) then
      indexes[#indexes + 1] = key
    else
      add_invalid_array_key(ctx, path, key)
    end
  end

  table.sort(indexes)

  for i = 1, #indexes do
    if indexes[i] ~= i then
      schema._add_issue(ctx, "error", {
        code = "sparse_array",
        path = issue.child_path(path, i),
        message = "Array entries must be contiguous",
        expected = "present array item",
        received = nil,
      })
      break
    end
  end

  return indexes
end

---@return Warden.Schema
function M.any()
  return schema.new("any", function(_, value)
    return schema._clone(value)
  end)
end

---@return Warden.Schema
function M.boolean()
  return schema.new("boolean", function(_, value, ctx, path)
    if type(value) ~= "boolean" then
      invalid_type(ctx, path, "invalid_type", "boolean", value)
      return nil
    end

    return value
  end)
end

---@return Warden.Schema
function M.string()
  return schema.new("string", function(_, value, ctx, path)
    if type(value) ~= "string" then
      invalid_type(ctx, path, "invalid_type", "string", value)
      return nil
    end

    return value
  end)
end

---@return Warden.Schema
function M.number()
  return schema.new("number", function(_, value, ctx, path)
    if type(value) ~= "number" then
      invalid_type(ctx, path, "invalid_type", "number", value)
      return nil
    end

    return value
  end)
end

---@return Warden.Schema
function M.integer()
  return schema.new("integer", function(_, value, ctx, path)
    if type(value) ~= "number" or value % 1 ~= 0 then
      invalid_type(ctx, path, "invalid_type", "integer", value)
      return nil
    end

    return value
  end)
end

---@return Warden.Schema
function M.table()
  return schema.new("table", function(_, value, ctx, path)
    if type(value) ~= "table" then
      invalid_type(ctx, path, "invalid_type", "table", value)
      return nil
    end

    return schema._clone(value)
  end)
end

---@param item_schema Warden.Schema
---@return Warden.Schema
function M.array(item_schema)
  return schema.new("array", function(_, value, ctx, path)
    if type(value) ~= "table" then
      invalid_type(ctx, path, "invalid_type", "array", value)
      return nil
    end

    local parsed = {}
    local indexes = validate_dense_array(ctx, path, value)

    for i = 1, #indexes do
      local index = indexes[i]
      local child_path = issue.child_path(path, index)
      local child, include = item_schema:_parse(value[index], ctx, child_path, true)
      if include then
        parsed[index] = child
      end
    end

    return parsed
  end)
end

---@param item_schemas Warden.Schema[]
---@return Warden.Schema
function M.tuple(item_schemas)
  return schema.new("tuple", function(_, value, ctx, path)
    if type(value) ~= "table" then
      invalid_type(ctx, path, "invalid_type", "tuple", value)
      return nil
    end

    local parsed = {}

    for key in pairs(value) do
      if not is_positive_integer(key) then
        schema._add_issue(ctx, "error", {
          code = "invalid_tuple_key",
          path = issue.child_path(path, key),
          message = "Tuple keys must be positive integers",
          expected = "positive integer key",
          received = key,
        })
      elseif key > #item_schemas then
        schema._add_issue(ctx, "error", {
          code = "unexpected_tuple_item",
          path = issue.child_path(path, key),
          message = "Tuple contains an unexpected item",
          expected = #item_schemas,
          received = key,
        })
      end
    end

    for i = 1, #item_schemas do
      local child_path = issue.child_path(path, i)
      if value[i] == nil then
        schema._add_issue(ctx, "error", {
          code = "required",
          path = child_path,
          message = "Required tuple item is missing",
          expected = "tuple item",
          received = nil,
        })
      else
        local child, include = item_schemas[i]:_parse(value[i], ctx, child_path, true)
        if include then
          parsed[i] = child
        end
      end
    end

    return parsed
  end)
end

---@param key_schema Warden.Schema
---@param value_schema Warden.Schema
---@return Warden.Schema
function M.map(key_schema, value_schema)
  return schema.new("map", function(_, value, ctx, path)
    if type(value) ~= "table" then
      invalid_type(ctx, path, "invalid_type", "map", value)
      return nil
    end

    local parsed = {}
    local seen = {}

    for key, child in pairs(value) do
      local child_path = issue.child_path(path, key)
      local key_ctx = {
        issues = {},
        warnings = {},
        options = ctx.options,
      }
      local parsed_key = key_schema:_parse(key, key_ctx, child_path, true)

      for i = 1, #key_ctx.issues do
        ctx.issues[#ctx.issues + 1] = key_ctx.issues[i]
      end

      for i = 1, #key_ctx.warnings do
        ctx.warnings[#ctx.warnings + 1] = key_ctx.warnings[i]
      end

      if #key_ctx.issues == 0 then
        if seen[parsed_key] then
          schema._add_issue(ctx, "error", {
            code = "duplicate_key",
            path = child_path,
            message = string.format("Map key normalizes to duplicate key %s", tostring(parsed_key)),
            expected = "unique normalized key",
            received = key,
          })
        else
          seen[parsed_key] = true
          local parsed_child, include = value_schema:_parse(child, ctx, child_path, true)
          if include then
            parsed[parsed_key] = parsed_child
          end
        end
      end
    end

    return parsed
  end)
end

---@param value_schema Warden.Schema
---@return Warden.Schema
function M.record(value_schema)
  return M.map(M.string(), value_schema)
end

---@param fields table<string,Warden.Schema>
---@return Warden.Schema
function M.object(fields)
  local object_schema

  object_schema = schema.new("object", function(self, value, ctx, path)
    if type(value) ~= "table" then
      invalid_type(ctx, path, "invalid_type", "object", value)
      return nil
    end

    local parsed = {}
    local seen = {}

    for key, child_schema in pairs(fields) do
      seen[key] = true
      local child_path = issue.child_path(path, key)
      local child, include = child_schema:_parse(value[key], ctx, child_path, value[key] ~= nil)

      if include then
        parsed[key] = child
      end
    end

    local unknown = self._unknown or ctx.options.unknown or schema._config.unknown

    for key, child in pairs(value) do
      if not seen[key] then
        local child_path = issue.child_path(path, key)

        if unknown == "error" then
          schema._add_issue(ctx, "error", {
            code = "unknown_key",
            path = child_path,
            message = string.format("Unknown key %s", tostring(key)),
            expected = "declared key",
            received = key,
          })
        elseif unknown == "warn" then
          schema._add_issue(ctx, "warning", {
            code = "unknown_key",
            path = child_path,
            message = string.format("Unknown key %s", tostring(key)),
            expected = "declared key",
            received = key,
          })
          parsed[key] = schema._clone(child)
        elseif unknown == "keep" then
          parsed[key] = schema._clone(child)
        end
      end
    end

    return parsed
  end)

  object_schema._fields = fields
  return object_schema
end

---@param values any[]
---@return Warden.Schema
function M.enum(values)
  return schema.new("enum", function(_, value, ctx, path)
    for i = 1, #values do
      if value == values[i] then
        return value
      end
    end

    schema._add_issue(ctx, "error", {
      code = "invalid_enum_value",
      path = path,
      message = "Expected one of: " .. join_values(values),
      expected = values,
      received = value,
    })

    return nil
  end)
end

---@param expected any
---@return Warden.Schema
function M.literal(expected)
  return schema.new("literal", function(_, value, ctx, path)
    if value ~= expected then
      schema._add_issue(ctx, "error", {
        code = "invalid_literal",
        path = path,
        message = string.format("Expected literal %s", tostring(expected)),
        expected = expected,
        received = value,
      })
      return nil
    end

    return value
  end)
end

---@param schemas Warden.Schema[]
---@return Warden.Schema
function M.union(schemas)
  return schema.new("union", function(_, value, ctx, path)
    local branches = {}

    for i = 1, #schemas do
      local branch_ctx = {
        issues = {},
        warnings = {},
        options = ctx.options,
      }
      local parsed = schemas[i]:_parse(value, branch_ctx, path, true)

      if #branch_ctx.issues == 0 then
        for j = 1, #branch_ctx.warnings do
          ctx.warnings[#ctx.warnings + 1] = branch_ctx.warnings[j]
        end
        return parsed
      end

      branches[#branches + 1] = {
        index = i,
        issues = branch_ctx.issues,
      }
    end

    schema._add_issue(ctx, "error", {
      code = "invalid_union",
      path = path,
      message = "Value did not match any union option",
      expected = "union",
      received = value,
      details = {
        branches = branches,
      },
    })

    return nil
  end)
end

return M
