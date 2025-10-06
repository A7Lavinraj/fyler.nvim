---@class Trie
---@field value any
---@field children table<string, Trie>
local Trie = {}
Trie.__index = Trie

---Create a new Trie node
---@param value any|nil
---@return Trie
function Trie.new(value)
  local instance = {
    value = value,
    children = {},
  }
  setmetatable(instance, Trie)
  return instance
end

---Insert a value at the given path segments
---@param segments string[]
---@param value any
---@return Trie -- returns the final node
function Trie:insert(segments, value)
  if #segments == 0 then
    self.value = value
    return self
  end

  local head = segments[1]
  if not self.children[head] then
    self.children[head] = Trie.new()
  end

  local rest = {}
  for i = 2, #segments do
    rest[#rest + 1] = segments[i]
  end

  return self.children[head]:insert(rest, value)
end

---Find a node at the given path segments
---@param segments string[]
---@return Trie|nil
function Trie:find(segments)
  if #segments == 0 then
    return self
  end

  local head = segments[1]
  if not self.children[head] then
    return nil
  end

  local rest = {}
  for i = 2, #segments do
    rest[#rest + 1] = segments[i]
  end

  return self.children[head]:find(rest)
end

---Delete a node at the given path segments
---@param segments string[]
---@return boolean -- true if deleted, false if not found
function Trie:delete(segments)
  if #segments == 0 then
    return false
  end

  if #segments == 1 then
    local head = segments[1]
    if self.children[head] then
      self.children[head] = nil
      return true
    end
    return false
  end

  local head = segments[1]
  if not self.children[head] then
    return false
  end

  local rest = {}
  for i = 2, #segments do
    rest[#rest + 1] = segments[i]
  end

  return self.children[head]:delete(rest)
end

return Trie
