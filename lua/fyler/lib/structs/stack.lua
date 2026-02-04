---@class Stack
---@field items table
local Stack = {}
Stack.__index = Stack

---@return Stack
function Stack.new() return setmetatable({ items = {} }, Stack) end

---@param data any
function Stack:push(data) table.insert(self.items, data) end

function Stack:pop()
  assert(not self:is_empty(), "stack is empty")

  return table.remove(self.items)
end

---@return any
function Stack:top()
  assert(not self:is_empty(), "stack is empty")
  return self.items[#self.items]
end

---@return integer
function Stack:size() return #self.items end

---@return boolean
function Stack:is_empty() return #self.items == 0 end

return Stack
