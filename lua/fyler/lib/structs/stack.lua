local List = require("fyler.lib.structs.list")

---@class Stack
---@field items LinkedList
local Stack = {}
Stack.__index = Stack

---@return Stack
function Stack.new() return setmetatable({ items = List.new() }, Stack) end

---@param data any
function Stack:push(data) self.items:insert(1, data) end

function Stack:pop()
  assert(not self:is_empty(), "stack is empty")

  local data = self.items.node.data
  self.items:erase(1)
  return data
end

---@return any
function Stack:top()
  assert(self.items.node, "stack is empty")
  return self.items.node.data
end

---@return integer
function Stack:size() return self.items:len() end

---@return boolean
function Stack:is_empty() return self.items:len() == 0 end

return Stack
