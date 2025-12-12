local util = require "fyler.lib.util"

---@class UiComponentOption
---@field highlight string|nil
---@field virt_text string[][]|nil
---@field col integer|nil

---@class UiComponent
---@field tag string
---@field value any
---@field parent UiComponent
---@field option UiComponentOption
---@field children UiComponent[]
local UiComponent = {}

---@param fn fun(...): table
---@return UiComponent
function UiComponent.new(fn)
  local instance = {}

  local mt = {
    __call = function(_, ...)
      local this = fn(...)

      setmetatable(this, { __index = UiComponent })

      return this
    end,

    __index = function(_, name)
      return rawget(UiComponent, name)
    end,
  }

  setmetatable(instance, mt)

  return instance
end

---@param fn fun(...)
---@return function
function UiComponent.new_async(fn)
  return function(...)
    local args = { ... }
    local cb = table.remove(args)

    table.insert(args, function(this, ...)
      cb(setmetatable(this, { __index = UiComponent }), ...)
    end)

    fn(util.unpack(args))
  end
end

function UiComponent:width()
  if self.tag == "text" then
    return string.len(self.value or self.option.virt_text[1][1])
  end

  if self.tag == "row" then
    local width = 0
    for i = 1, #self.children do
      width = width + self.children[i]:width()
    end

    return width
  end

  if self.children then
    local width = 0
    for i = 1, #self.children do
      local c_width = self.children[i]:width()
      if c_width > width then
        width = c_width
      end
    end

    return width
  end

  error "UNIMPLEMENTED"
end

function UiComponent:height()
  if self.tag == "text" then
    return 1
  end

  if self.tag == "row" then
    local max_height = 0
    for i = 1, #self.children do
      local child_height = self.children[i]:height()
      if child_height > max_height then
        max_height = child_height
      end
    end
    return max_height
  end

  if self.children then
    local total_height = 0
    for i = 1, #self.children do
      total_height = total_height + self.children[i]:height()
    end
    return total_height
  end

  error "UNIMPLEMENTED"
end

return UiComponent
