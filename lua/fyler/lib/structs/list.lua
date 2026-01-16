---@class LinkedList
---@field node LinkedListNode
local LinkedList = {}
LinkedList.__index = LinkedList

---@class LinkedListNode
---@field next LinkedListNode|nil
---@field data any
local LinkedListNode = {}
LinkedListNode.__index = LinkedListNode

---@return LinkedList
function LinkedList.new() return setmetatable({}, LinkedList) end

---@return integer
function LinkedList:len()
  local count = 0
  local current = self.node
  while current do
    count = count + 1
    current = current.next
  end

  return count
end

---@param fn fun(node: LinkedListNode)
function LinkedList:each(fn)
  local start = self.node
  while start do
    fn(start.data)
    start = start.next
  end
end

---@param pos integer
---@param data any
function LinkedList:insert(pos, data)
  local newNode = setmetatable({ data = data }, LinkedListNode)
  if pos == 1 then
    newNode.next = self.node
    self.node = newNode
    return
  end

  local start = self.node
  for _ = 1, pos - 2 do
    if not start then error("position is out of bound") end
    start = start.next
  end

  if not start then error("position is out of bound") end

  newNode.next = start.next
  start.next = newNode
end

---@param pos integer
function LinkedList:erase(pos)
  assert(pos >= 1, "position must be 1 or greater")

  if not self.node then error("list is empty") end

  if pos == 1 then
    self.node = self.node.next
    return
  end

  local start = self.node
  for _ = 1, pos - 2 do
    if not start or not start.next then error("position is out of bound") end

    start = start.next
  end

  if not start or not start.next then error("position is out of bound") end

  start.next = start.next.next
end

---@return table
function LinkedList:totable()
  local tbl = {}
  self:each(function(item) table.insert(tbl, item) end)

  return tbl
end

return LinkedList
