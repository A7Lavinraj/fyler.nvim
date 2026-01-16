local Component = require("fyler.lib.ui.component")
local Renderer = require("fyler.lib.ui.renderer")

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

Ui.Text = Ui.Component.new(
  function(value, option)
    return {
      tag = "text",
      value = value,
      option = option,
      children = {},
    }
  end
)

---@param win Win
---@return Ui
function Ui.new(win) return setmetatable({ win = win, renderer = Renderer.new() }, Ui) end

---@param component UiComponent
Ui.render = vim.schedule_wrap(function(self, component, ...)
  local opts = {}
  local onrender = nil

  for i = 1, select("#", ...) do
    local arg = select(i, ...)

    if type(arg) == "table" then
      opts = arg
    elseif type(arg) == "function" then
      onrender = arg
    end
  end

  -- Render Ui components to neovim api compatible
  self.renderer:render(component)

  if not opts.partial then
    -- Clear namespace and sets renderer lines from given Ui component
    self.win:set_lines(0, -1, self.renderer.line)
  end

  for _, highlight in ipairs(self.renderer.highlight) do
    -- stylua: ignore start
    self.win:set_extmark(highlight.line, highlight.col_start, {
      end_col  = highlight.col_end,
      hl_group = highlight.highlight_group,
    })
    -- stylua: ignore end
  end

  for _, extmark in ipairs(self.renderer.extmark) do
    -- stylua: ignore start
    self.win:set_extmark(extmark.line, 0, {
      hl_mode           = extmark.hl_mode,
      virt_text         = extmark.virt_text,
      virt_text_pos     = extmark.virt_text_pos,
      virt_text_win_col = extmark.col,
    })
    -- stylua: ignore end
  end

  pcall(onrender)
end)

return Ui
