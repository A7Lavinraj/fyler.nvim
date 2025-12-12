local Ui = require "fyler.lib.ui"
local Win = require "fyler.lib.win"
local util = require "fyler.lib.util"

local Confirm = {}
Confirm.__index = Confirm

local function resolve_dim(width, height)
  local width = math.max(25, math.min(vim.o.columns, width))
  local height = math.max(1, math.min(16, height))
  local left = ((vim.o.columns - width) * 0.5)
  local top = ((vim.o.lines - height) * 0.5)
  return math.floor(width), math.floor(height), math.floor(left), math.floor(top)
end

---@param options table
function Confirm:open(options, message, onsubmit)
  local width, height, left, top = resolve_dim(options.width, options.height)

  self.bufnr = vim.api.nvim_create_buf(false, true)
  self.namespace = vim.api.nvim_create_namespace("fyler_confirm_" .. self.bufnr)
  self.ui = Ui.new(self)

  -- stylua: ignore start
  self.window = Win.new {
    bufnr      = self.bufnr,
    autocmds   = {
      QuitPre = function()
        local cmd = util.cmd_history()
        self:hide()

        onsubmit()
        if cmd == "qa" or cmd == "qall" or cmd == "quitall" then
          vim.schedule(function()
            vim.cmd.quitall {
              bang = true
            }
          end)
        end
      end
    },
    border     = vim.o.winborder == "" and "rounded" or vim.o.winborder,
    enter      = true,
    footer     = " Want to continue? (y|n) ",
    footer_pos = "center",
    height     = height,
    kind       = "float",
    left       = left,
    top        = top,
    width      = width,
    win_opts   = {
      winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC"
    }
  }
  -- stylua: ignore end

  self.window:show()

  util.set_buf_option(self.bufnr, "modifiable", false)

  local mappings_opts = { buffer = self.bufnr }
  for _, k in ipairs { "y", "o", "<Enter>" } do
    vim.keymap.set("n", k, function()
      self:hide()
      onsubmit(true)
    end, mappings_opts)
  end
  for _, k in ipairs { "n", "c", "<ESC>" } do
    vim.keymap.set("n", k, function()
      self:hide()
      onsubmit(false)
    end, mappings_opts)
  end

  if type(message) == "table" and type(message[1]) == "string" then
    ---@diagnostic disable-next-line: param-type-mismatch
    self.ui:render(Ui.Column(util.tbl_map(message, Ui.Text)))
  else
    self.ui:render(message)
  end
end

function Confirm:set_lines(start, finish, lines)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end

  local was_modifiable = util.get_buf_option(self.bufnr, "modifiable")
  util.set_buf_option(self.bufnr, "modifiable", true)

  vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace, 0, -1)
  vim.api.nvim_buf_set_lines(self.bufnr, start, finish, false, lines)

  if not was_modifiable then
    util.set_buf_option(self.bufnr, "modifiable", false)
  end
end

function Confirm:set_extmark(row, col, options)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, row, col, options)
  end
end

function Confirm:hide()
  self.window:hide()
  -- Delete the buffer since this is a one-time dialog
  util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })
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
