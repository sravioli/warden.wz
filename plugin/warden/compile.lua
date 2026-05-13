---@module "warden.compile"

local types = require "warden.types"

local M = {}

---@param spec table|Warden.Schema
---@return boolean
local function is_schema(spec)
  return type(spec) == "table" and type(spec.safe_parse) == "function"
end

---@param schema Warden.Schema
---@param spec table
---@return Warden.Schema
local function apply_modifiers(schema, spec)
  if spec.optional then
    schema:optional()
  end

  if spec.required then
    schema:required()
  end

  if spec.nullable then
    schema:nullable()
  end

  if spec.default ~= nil then
    schema:default(spec.default)
  end

  if spec.description then
    schema:describe(spec.description)
  end

  if spec.unknown then
    schema:unknown(spec.unknown)
  end

  if spec.min ~= nil and spec.max ~= nil then
    schema:range(spec.min, spec.max)
  else
    if spec.min ~= nil then
      schema:min(spec.min)
    end
    if spec.max ~= nil then
      schema:max(spec.max)
    end
  end

  if spec.pattern then
    schema:matches(spec.pattern)
  end

  if spec.not_empty then
    schema:not_empty()
  end

  if spec.refine then
    schema:refine(spec.refine, spec.message)
  end

  return schema
end

---@param spec table|Warden.Schema
---@return Warden.Schema
function M.compile(spec)
  if is_schema(spec) then
    return spec
  end

  if type(spec) ~= "table" then
    error("Warden schema spec must be a table", 2)
  end

  local compiled
  local kind = spec.type

  if spec.enum then
    compiled = types.enum(spec.enum)
  elseif spec.literal ~= nil then
    compiled = types.literal(spec.literal)
  elseif spec.union then
    local branches = {}
    for i = 1, #spec.union do
      branches[i] = M.compile(spec.union[i])
    end
    compiled = types.union(branches)
  elseif kind == "any" then
    compiled = types.any()
  elseif kind == "boolean" then
    compiled = types.boolean()
  elseif kind == "string" then
    compiled = types.string()
  elseif kind == "number" then
    compiled = types.number()
  elseif kind == "integer" then
    compiled = types.integer()
  elseif kind == "table" then
    compiled = types.table()
  elseif kind == "array" then
    compiled = types.array(M.compile(spec.items or { type = "any" }))
  elseif kind == "map" then
    compiled = types.map(M.compile(spec.keys), M.compile(spec.values))
  elseif kind == "record" then
    compiled = types.record(M.compile(spec.values))
  elseif kind == "object" or spec.fields then
    local fields = {}
    for name, field in pairs(spec.fields or {}) do
      fields[name] = M.compile(field)
    end
    compiled = types.object(fields)
  else
    error("Unknown Warden schema type: " .. tostring(kind), 2)
  end

  return apply_modifiers(compiled, spec)
end

return M
