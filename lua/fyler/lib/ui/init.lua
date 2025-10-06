local Component = require "fyler.lib.ui.component"
local Renderer = require "fyler.lib.ui.renderer"
local util = require "fyler.lib.util"

---@class Ui
---@field win Win
---@field renderer UiRenderer
local Ui = {}
Ui.__index = Ui

Ui.Component = Component

---@param children UiComponent[]
Ui.Column = Ui.Component.new(function(children)
  return {
    tag = "column",
    children = children,
  }
end)

---@param children UiComponent[]
Ui.Row = Ui.Component.new(function(children)
  return {
    tag = "row",
    children = children,
  }
end)

Ui.Text = Ui.Component.new(function(value, option)
  return {
    tag = "text",
    value = value,
    option = option,
    children = {},
  }
end)

---@param win Win
---@return Ui
function Ui.new(win)
  local instance = {
    win = win,
    renderer = Renderer.new(),
  }

  setmetatable(instance, Ui)

  return instance
end

---@param component UiComponent
function Ui:_render(component)
  if not self.win:has_valid_bufnr() then
    return
  end

  local was_modifiable = util.get_buf_option(self.win.bufnr, "modifiable")
  local undolevels = util.get_buf_option(self.win.bufnr, "undolevels")

  util.set_buf_option(self.win.bufnr, "modifiable", true)
  util.set_buf_option(self.win.bufnr, "undolevels", -1)

  self.renderer:render(component)

  vim.api.nvim_buf_set_lines(self.win.bufnr, 0, -1, false, self.renderer.line)
  vim.api.nvim_buf_clear_namespace(self.win.bufnr, self.win.namespace, 0, -1)

  for _, highlight in ipairs(self.renderer.highlight) do
    vim.api.nvim_buf_set_extmark(self.win.bufnr, self.win.namespace, highlight.line, highlight.col_start, {
      end_col = highlight.col_end,
      hl_group = highlight.highlight_group,
    })
  end

  for _, extmark in ipairs(self.renderer.extmark) do
    vim.api.nvim_buf_set_extmark(self.win.bufnr, self.win.namespace, extmark.line, 0, {
      virt_text = extmark.virt_text,
      virt_text_pos = extmark.virt_text_pos,
      virt_text_win_col = extmark.col,
      hl_mode = extmark.hl_mode,
    })
  end

  if not was_modifiable then
    util.set_buf_option(self.win.bufnr, "modifiable", false)
  end

  util.set_buf_option(self.win.bufnr, "modified", false)
  util.set_buf_option(self.win.bufnr, "undolevels", undolevels)
end

function Ui:render(component, callback)
  vim.schedule(function()
    self:_render(component)

    if callback then
      callback()
    end
  end)
end

return Ui
