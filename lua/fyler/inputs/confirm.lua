local Ui = require "fyler.lib.ui"
local Win = require "fyler.lib.win"
local a = require "fyler.lib.async"
local util = require "fyler.lib.util"

local function quit(win, onsubmit)
  return function()
    local cmd = util.cmd_history()
    win:hide()
    onsubmit()

    if cmd == "qa" or cmd == "qall" or cmd == "quitall" then
      vim.schedule(function()
        vim.cmd.quitall { bang = true }
      end)
    end
  end
end

local function confirm(win, onsubmit)
  return function()
    win:hide()
    onsubmit(true)
  end
end

local function discard(win, onsubmit)
  return function()
    win:hide()
    onsubmit(false)
  end
end

---@class FylerInputsConfirm
local M = {}

local Confirm = {}
Confirm.__index = Confirm

---@return boolean
local function is_tos(a)
  return type(a) == "table" and type(a[1]) == "string"
end

local function border()
  return vim.o.winborder == "" and "rounded" or vim.o.winborder
end

M.open = vim.schedule_wrap(function(msg, cb)
  local win = Win.new {
    border = border(),
    buf_opts = { modifiable = false },
    enter = true,
    height = "0.3rel",
    kind = "float",
    left = "0.3rel",
    top = "0.35rel",
    width = "0.4rel",
    win_opts = { winhighlight = "Normal:FylerNormal,FloatTitle:FylerBorder,FloatBorder:FylerBorder" },
  }

  win.autocmds = { ["QuitPre"] = quit(win, cb) }
  win.mappings = { ["y"] = confirm(win, cb), ["n"] = discard(win, cb), ["<esc>"] = quit(win, cb) }
  win.render = function()
    win.ui:render(is_tos(msg) and Ui.Row(util.tbl_map(msg, function(line)
      return Ui.Text(line)
    end)) or msg)
  end

  win:show()
end)

M.open_async = a.wrap(M.open)

return M
