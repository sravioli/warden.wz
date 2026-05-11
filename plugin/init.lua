---@class Wezterm
local wz = require "wezterm" --[[@as Wezterm]]

---Locate the plugin's `plugin_dir` and add it to `package.path`.
---
---Iterates the installed WezTerm plugins looking for one whose URL
---contains `name`. When found, appends the plugin's
---`plugin_dir/plugin/?.lua` entry to `package.path` so that
---sub-modules can be loaded with `require`. Does nothing if the
---path entry already exists or no matching plugin is found.
---
---@param name string Substring to match against plugin URLs.
---@return nil
local function bootstrap(name)
  -- selene: allow(incorrect_standard_library_use)
  local sep = package.config:sub(1, 1)

  local plugins = wz.plugin.list()
  for i = 1, #plugins do
    local p = plugins[i]
    if p.url:find(name, 1, true) then
      local entries = {
        p.plugin_dir .. sep .. "plugin" .. sep .. "?.lua",
        p.plugin_dir .. sep .. "plugin" .. sep .. "?" .. sep .. "init.lua",
      }

      for j = 1, #entries do
        if not package.path:find(entries[j], 1, true) then
          package.path = package.path .. ";" .. entries[j]
        end
      end

      return
    end
  end
end

bootstrap "warden.wz"

return require "warden.api"
