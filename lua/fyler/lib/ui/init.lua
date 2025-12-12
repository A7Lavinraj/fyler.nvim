local Component = require "fyler.lib.ui.component"
local Renderer = require "fyler.lib.ui.renderer"

---@class Ui
---@field win Win|Finder  -- Any object with set_lines and set_extmark methods
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
---@param on_render function|nil
Ui.render = vim.schedule_wrap(function(self, component, on_render)
  -- Render Ui components to neovim api compatible
  self.renderer:render(component)

  -- Clear namespace and sets renderer lines from given Ui component
  self.win:set_lines(0, -1, self.renderer.line)

  for _, highlight in ipairs(self.renderer.highlight) do
    self.win:set_extmark(highlight.line, highlight.col_start, {
      end_col = highlight.col_end,
      hl_group = highlight.highlight_group,
    })
  end

  for _, extmark in ipairs(self.renderer.extmark) do
    self.win:set_extmark(extmark.line, 0, {
      virt_text = extmark.virt_text,
      virt_text_pos = extmark.virt_text_pos,
      virt_text_win_col = extmark.col,
      hl_mode = extmark.hl_mode,
    })
  end

  if on_render then
    on_render()
  end
end)

return Ui
