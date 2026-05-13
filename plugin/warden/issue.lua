---@module "warden.issue"

local M = {}

local function is_identifier(segment)
  return type(segment) == "string" and string.match(segment, "^[%a_][%w_]*$") ~= nil
end

local function quote_segment(segment)
  return string.format('["%s"]', tostring(segment):gsub("\\", "\\\\"):gsub('"', '\\"'))
end

---@param path any[]?
---@return any[]
function M.clone_path(path)
  local cloned = {}
  if not path then
    return cloned
  end

  for i = 1, #path do
    cloned[i] = path[i]
  end

  return cloned
end

---@param path any[]?
---@return string
function M.path_text(path)
  if not path or #path == 0 then
    return "<root>"
  end

  local parts = {}

  for i = 1, #path do
    local segment = path[i]
    if type(segment) == "number" then
      parts[#parts + 1] = string.format("[%d]", segment)
    elseif is_identifier(segment) and #parts == 0 then
      parts[#parts + 1] = tostring(segment)
    elseif is_identifier(segment) then
      parts[#parts + 1] = "." .. tostring(segment)
    elseif #parts == 0 then
      parts[#parts + 1] = quote_segment(segment)
    else
      parts[#parts + 1] = quote_segment(segment)
    end
  end

  return table.concat(parts, "")
end

---@param path any[]?
---@param key any
---@return any[]
function M.child_path(path, key)
  local child = M.clone_path(path)
  child[#child + 1] = key
  return child
end

---@param spec table
---@return Warden.Issue
function M.new(spec)
  local path = M.clone_path(spec.path)

  ---@class Warden.Issue
  ---@field code string
  ---@field path any[]
  ---@field path_text string
  ---@field message string
  ---@field expected any
  ---@field received any
  ---@field severity "error"|"warning"
  ---@field description string?
  ---@field details table?
  local issue = {
    code = spec.code or "custom",
    path = path,
    path_text = M.path_text(path),
    message = spec.message or "Invalid value",
    expected = spec.expected,
    received = spec.received,
    severity = spec.severity or "error",
    description = spec.description,
    details = spec.details,
  }

  return issue
end

return M
