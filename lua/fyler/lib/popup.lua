local Win = require "fyler.lib.win"

---@class Popup
---@field win Win
---@field config table
local Popup = {}
Popup.__index = Popup

local winhighlight = table.concat({
  "Normal:FylerNormal",
  "FloatBorder:FylerBorder",
  "FloatTitle:FylerBorder",
}, ",")

---@return Popup
function Popup.new()
  local instance = {
    config = {
      buf_opts = {},
      win_opts = {
        winhighlight = winhighlight,
      },
      mappings = {},
    },
  }

  setmetatable(instance, Popup)

  return instance
end

---@param border string|string[]
function Popup:border(border)
  self.config.border = border
  return self
end

---@param option string
---@param value any
function Popup:buf_opt(option, value)
  self.config.buf_opts[option] = value
  return self
end

---@param option string
---@param value any
function Popup:win_opt(option, value)
  self.config.win_opts[option] = value
  return self
end

function Popup:enter()
  self.config.enter = true
  return self
end

---@param height string
function Popup:height(height)
  self.config.height = height
  return self
end

---@param kind WinKind
function Popup:kind(kind)
  self.config.kind = kind
  return self
end

---@param left string
function Popup:left(left)
  self.config.left = left
  return self
end

---@param k string
---@param a function
function Popup:action(k, a)
  self.config.mappings[k] = a(self)
  return self
end

function Popup:render(fn)
  self.config.render = fn(self)
  return self
end

---@param top string
function Popup:top(top)
  self.config.top = top
  return self
end

---@param width string
function Popup:width(width)
  self.config.width = width
  return self
end

function Popup:create()
  self.win = Win.new(self.config)
  self.win:show()
end

return Popup
