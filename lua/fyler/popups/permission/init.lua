local Popup = require "fyler.lib.popup"
local a = require "fyler.lib.async"
local ui = require "fyler.popups.permission.ui"

---@class PopupPermission
local M = {}
M.__index = M

---@param message { str: string, hlg: string }[]
---@param on_choice fun(choice: boolean)
M.create = a.wrap(vim.schedule_wrap(function(message, on_choice)
  local config = require "fyler.config"
  local cfg = config.values.popup.permission
  local util = require "fyler.lib.util"

  local popup = Popup.new()

  if cfg.enter then popup:enter() end
  if cfg.border then popup:border(cfg.border) end
  if cfg.height then popup:height(cfg.height) end
  if cfg.kind then popup:kind(cfg.kind) end
  if cfg.left then popup:left(cfg.left) end
  if cfg.top then popup:top(cfg.top) end
  if cfg.width then popup:width(cfg.width) end

  for option, value in pairs(cfg.buf_opts or {}) do
    popup:buf_opt(option, value)
  end

  for _, k in ipairs(util.tbl_wrap(cfg.keys.accept)) do
    popup:action(k, function(self)
      return function()
        self.win:hide()
        on_choice(true)
      end
    end)
  end

  for _, k in ipairs(util.tbl_wrap(cfg.keys.reject)) do
    popup:action(k, function(self)
      return function()
        self.win:hide()
        on_choice(false)
      end
    end)
  end

  popup:render(function(self)
    return function()
      self.win.ui:render {
        ui_lines = ui(message),
      }
    end
  end)

  popup:create()
end))

return M
