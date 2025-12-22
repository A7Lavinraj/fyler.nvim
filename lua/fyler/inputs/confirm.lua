local Ui = require "fyler.lib.ui"
local Win = require "fyler.lib.win"
local util = require "fyler.lib.util"

local Confirm = {}
Confirm.__index = Confirm

local function resolve_dim(width, height)
  width = math.max(25, math.min(vim.o.columns, width))
  height = math.max(1, math.min(16, height))
  local left = math.floor((vim.o.columns - width) * 0.5)
  local top = math.floor((vim.o.lines - height) * 0.5)
  return math.floor(width), math.floor(height), left, top
end

function Confirm:open(options, message, onsubmit)
  local width, height, left, top = resolve_dim(options.width, options.height)
  -- stylua: ignore start
  self.window = Win.new {
    kind       = "float",
    enter      = true,
    width      = width,
    height     = height,
    left       = left,
    top        = top,
    border     = vim.o.winborder == "" and "rounded" or vim.o.winborder,
    footer     = " Want to continue? (y|n) ",
    footer_pos = "center",
    buf_opts   = { modifiable = false },
    win_opts   = { winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC" },
    mappings   = {
      [{ 'y', 'o', '<Enter>' }] = function()
        self.window:hide()
        onsubmit(true)
      end,
      [{ 'n', 'c', '<ESC>' }] = function()
        self.window:hide()
        onsubmit(false)
      end
    },
    autocmds   = {
      QuitPre = function()
        local cmd = util.cmd_history()
        self.window:hide()
        pcall(onsubmit)
        if cmd == "qa" or cmd == "qall" or cmd == "quitall" then
          vim.schedule(vim.cmd.quitall)
        end
      end
    },
    render     = function()
      if type(message) == "table" and type(message[1]) == "string" then
        ---@diagnostic disable-next-line: param-type-mismatch
        self.window.ui:render(Ui.Column(util.tbl_map(message, Ui.Text)))
      else
        self.window.ui:render(message)
      end
    end
  }
  -- stylua: ignore end

  self.window:show()
end

local M = {}

function M.open(message, on_submit)
  local width, height = 0, 0
  if message.width then
    width, height = message:width(), message:height()
  else
    height = #message
    for _, row in pairs(message) do
      width = math.max(width, #row)
    end
  end

  setmetatable({}, Confirm):open({
    width = width,
    height = height,
  }, message, on_submit)
end

return M
