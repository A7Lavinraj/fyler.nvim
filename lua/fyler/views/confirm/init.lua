local Win = require("fyler.lib.win")
local a = require("fyler.lib.async")
local config = require("fyler.config")
local ui = require("fyler.views.confirm.ui")
local util = require("fyler.lib.util")

---@class FylerConfirmView
---@field win FylerWin
local FylerConfirmView = {}
FylerConfirmView.__index = FylerConfirmView

---@param message { str: string, hl: string }[]
---@param choices string
---@param on_choice fun(choice: boolean)
function FylerConfirmView:open(message, choices, on_choice)
  local view_config = config.get_view_config("confirm")
  local mappings = {}

  util.tbl_each(config.get_mappings("confirm"), function(key, action)
    if type(action) == "function" then
      -- if action is a function, wrap it to pass self as the
      -- first argument
      mappings[key] = function() action(self, on_choice) end
      return
    elseif type(action) == "string" then
      local success, native_action =
        pcall(self._action, self, util.camel_to_snake(string.format("n%s", action)), on_choice)
      if not success or native_action == nil then
        vim.notify("" .. string.format("Mapping action %s is not available", action), vim.log.levels.WARN)
        return
      end
      mappings[key] = native_action
    end
  end)

  -- stylua: ignore start
  self.win = Win.new {
    autocmds = {
      ["QuitPre"] = self:_action("n_close_view", on_choice),
    },
    border   = view_config.win.border,
    bottom   = view_config.win.bottom,
    buf_opts = view_config.win.buf_opts,
    enter    = true,
    height   = view_config.win.height,
    kind     = view_config.win.kind,
    left     = view_config.win.left,
    name     = "Confirm",
    mappings = mappings,
    render = function()
      self.win.ui:render({ ui_lines = ui.Confirm(message) })
    end,
    right    = view_config.win.right,
    title    = string.format(" Confirm %s ", choices),
    top      = view_config.win.top,
    width    = view_config.win.width,
    win_opts = view_config.win.win_opts,
  }
  -- stylua: ignore end

  self.win:show()
end

function FylerConfirmView:close() self.win:hide() end

---@param name string
function FylerConfirmView:_action(name, ...)
  local action = require("fyler.views.confirm.actions")[name]
  assert(action, string.format("%s action is not available", name))

  return action(self, ...)
end

local M = {}

M.open = a.wrap(vim.schedule_wrap(
  ---@param message { str: string, hl: string }[]
  ---@param choices string
  ---@param on_choice fun(c: boolean)
  function(message, choices, on_choice) setmetatable({}, FylerConfirmView):open(message, choices, on_choice) end
))

return M
