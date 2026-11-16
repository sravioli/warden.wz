---Minimal config for bug reports. Run it in isolation from your own config:
---
---    wezterm --config-file minit.lua
---
---Put your reproduction below the marker. Keep it as small as possible and
---paste the edited file into the bug report.
local wezterm = require "wezterm"
local warden = wezterm.plugin.require "https://github.com/sravioli/warden.wz"
local config = wezterm.config_builder()

-- Edit below this line --------------------------------------------------------

local schema = warden.object {
  opacity = warden.number():range(0, 1):default(0.9),
}
local settings = schema:parse {}
config.window_background_opacity = settings.opacity

return config
