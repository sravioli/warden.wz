describe("warden.logger", function()
  local saved_logger, saved_wezterm

  before_each(function()
    saved_logger = package.loaded["warden.logger"]
    saved_wezterm = package.loaded.wezterm
    package.loaded["warden.logger"] = nil
  end)

  after_each(function()
    package.loaded["warden.logger"] = saved_logger
    package.loaded.wezterm = saved_wezterm
  end)

  it("uses a logger with a method named after the level", function()
    local got
    local logger = require "warden.logger"
    logger.emit("warn", "m", {
      warn = function(message)
        got = message
      end,
    })
    assert.are.equal("m", got)
  end)

  it("uses a wezterm-style log_<level> method", function()
    local got
    require("warden.logger").emit("error", "m", {
      log_error = function(message)
        got = message
      end,
    })
    assert.are.equal("m", got)
  end)

  it("uses a generic log(level, message) method", function()
    local got
    require("warden.logger").emit("info", "m", {
      log = function(level, message)
        got = level .. ":" .. message
      end,
    })
    assert.are.equal("info:m", got)
  end)

  it("falls back to wezterm, and stays silent without it", function()
    local got
    package.loaded.wezterm = {
      log_warn = function(message)
        got = message
      end,
    }
    local logger = require "warden.logger"
    logger.emit("warn", "from wezterm", {}) -- a target with no usable method
    assert.are.equal("from wezterm", got)

    got = nil
    logger.emit("debug", "no such function") -- wezterm lacks log_debug
    assert.is_nil(got)

    package.loaded["warden.logger"] = nil
    package.loaded.wezterm = nil
    package.preload.wezterm = function()
      error "no wezterm"
    end
    local bare = require "warden.logger"
    package.preload.wezterm = nil
    assert.has_no.errors(function()
      bare.emit("warn", "nobody listens")
    end)
  end)
end)
