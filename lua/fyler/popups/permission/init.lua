local Popup = require "fyler.lib.popup"
local a = require "fyler.lib.async"
local config = require "fyler.config"
local ui = require "fyler.popups.permission.ui"

---@class PopupPermission
local M = {}
M.__index = M

---@param message { str: string, hlg: string }[]
---@param on_choice fun(choice: boolean)
M.create = a.wrap(vim.schedule_wrap(function(message, on_choice)
  local popup = config.build_popup "permission"
  Popup.new()
    :action("y", function(self)
      return function()
        self.win:hide()
        on_choice(true)
      end
    end)
    :action("n", function(self)
      return function()
        self.win:hide()
        on_choice(false)
      end
    end)
    :border(popup.border)
    :buf_opt("modifiable", false)
    :enter()
    :height(popup.height)
    :kind("float")
    :left(popup.left)
    :render(function(self)
      return function()
        self.win.ui:render {
          ui_lines = ui(message),
        }
      end
    end)
    :top(popup.top)
    :width(popup.width)
    :create()
end))

return M
