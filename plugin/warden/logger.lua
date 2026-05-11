---@module "warden.logger"

local M = {}

---@type Wezterm?
local wezterm
local has_wezterm, loaded = pcall(require, "wezterm")
if has_wezterm then
  wezterm = loaded
end

---@param logger? table
---@param level string
---@return function?
local function resolve_logger(logger, level)
  if not logger then
    return nil
  end

  if type(logger[level]) == "function" then
    return function(message)
      logger[level](message)
    end
  end

  local wezterm_style = "log_" .. level
  if type(logger[wezterm_style]) == "function" then
    return function(message)
      logger[wezterm_style](message)
    end
  end

  if type(logger.log) == "function" then
    return function(message)
      logger.log(level, message)
    end
  end

  return nil
end

---@param level "debug"|"info"|"warn"|"error"
---@param message string
---@param logger? table
function M.emit(level, message, logger)
  local emit = resolve_logger(logger, level)
  if emit then
    emit(message)
    return
  end

  if not wezterm then
    return
  end

  local wezterm_style = "log_" .. level
  if type(wezterm[wezterm_style]) == "function" then
    wezterm[wezterm_style](message)
  end
end

return M
