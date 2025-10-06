local Manager = require "fyler.views.finder.files.manager"
local Path = require "fyler.lib.path"
local Trie = require "fyler.lib.structs.trie"
local fs = require "fyler.lib.fs"
local util = require "fyler.lib.util"

---@class Files
---@field trie Trie
---@field manager EntryManager
---@field root_path string
local Files = {}
Files.__index = Files

---@param opts EntryOpts
---@return Files
function Files.new(opts)
  assert(opts.type == "directory", "Files root must be a directory")

  local instance = {}
  instance.manager = Manager.new()
  instance.root_path = opts.path

  local ref_id = instance.manager:set(opts)
  instance.trie = Trie.new(ref_id)

  setmetatable(instance, Files)
  return instance
end

---@param path string
---@return string[]|nil
function Files:path_to_segments(path)
  if not vim.startswith(path, self.root_path) then
    return nil
  end

  local relative = path:sub(#self.root_path + 1)
  if relative:sub(1, 1) == "/" then
    relative = relative:sub(2)
  end

  if relative == "" then
    return {}
  end

  return util.filter_bl(vim.split(relative, "/"))
end

---@param ref_id integer
---@return Entry
function Files:node_entry(ref_id)
  assert(ref_id, "cannot find node without ref_id")
  return self.manager:get(ref_id)
end

---@param ref_id integer
---@return Trie|nil
function Files:find_node_by_ref_id(ref_id)
  local entry = self.manager:get(ref_id)
  local segments = self:path_to_segments(entry.path)
  if not segments then
    return nil
  end
  return self.trie:find(segments)
end

---@param ref_id integer
function Files:expand_node(ref_id)
  local entry = self.manager:get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")
  entry.open = true
end

---@param ref_id integer
function Files:collapse_node(ref_id)
  local entry = self.manager:get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")
  entry.open = false
end

---@param ref_id integer
---@return integer|nil
function Files:find_parent(ref_id)
  local entry = self.manager:get(ref_id)
  local segments = self:path_to_segments(entry.path)

  if not segments or #segments == 0 then
    return nil
  end

  local parent_segments = {}
  for i = 1, #segments - 1 do
    parent_segments[i] = segments[i]
  end

  if #parent_segments == 0 then
    return self.trie.value
  end

  local parent_node = self.trie:find(parent_segments)
  return parent_node and parent_node.value or nil
end

function Files:collapse_all()
  for _, child in pairs(self.trie.children) do
    self:_collapse_recursive(child)
  end
end

---@param node Trie
function Files:_collapse_recursive(node)
  local entry = self.manager:get(node.value)
  if entry:isdir() and entry.open then
    entry.open = false
  end

  for _, child in pairs(node.children) do
    self:_collapse_recursive(child)
  end
end

---@param parent_ref_id integer
---@param opts EntryOpts
function Files:add_child(parent_ref_id, opts)
  local parent_entry = self.manager:get(parent_ref_id)

  opts.path = Path.new(parent_entry.path):joinpath(opts.name):abspath()

  local child_ref_id = self.manager:set(opts)

  local parent_segments = self:path_to_segments(parent_entry.path)
  local parent_node = self.trie:find(parent_segments or {})

  if parent_node then
    parent_node.children[opts.name] = Trie.new(child_ref_id)
  end
end

---@param ref_id integer|nil
---@return Files
function Files:update(ref_id)
  if ref_id then
    local node = self:find_node_by_ref_id(ref_id)
    if not node then
      return self
    end
    self:_update(node)
  else
    self:_update(self.trie)
  end
  return self
end

---@param node Trie
function Files:_update(node)
  local node_entry = self.manager:get(node.value)
  if not node_entry.open then
    return
  end

  local entries = fs.ls(node_entry.path)

  local entry_paths = {}
  for _, entry in ipairs(entries) do
    entry_paths[entry.name] = entry
  end

  for name, _ in pairs(node.children) do
    if not entry_paths[name] then
      node.children[name] = nil
    end
  end

  for name, entry in pairs(entry_paths) do
    if not node.children[name] then
      local child_ref_id = self.manager:set(entry)
      node.children[name] = Trie.new(child_ref_id)
    end
  end

  for _, child in pairs(node.children) do
    self:_update(child)
  end
end

---@param path string
---@return integer|nil
function Files:focus_path(path)
  local segments = self:path_to_segments(path)
  if not segments then
    return nil
  end

  if #segments == 0 then
    return nil
  end

  local current_node = self.trie

  for _, segment in ipairs(segments) do
    local current_entry = self.manager:get(current_node.value)
    if current_entry:isdir() and not current_entry.open then
      self:expand_node(current_node.value)
      self:update(current_node.value)
    end

    if not current_node.children[segment] then
      return nil
    end

    current_node = current_node.children[segment]
  end

  return current_node.value
end

---@return table
function Files:totable()
  return self:_totable(self.trie)
end

---@param node Trie
---@return table
function Files:_totable(node)
  local entry = self.manager:get(node.value)

  local table_node = {
    link = entry.link,
    name = entry.name,
    open = entry.open,
    path = entry.path,
    ref_id = node.value,
    type = entry.type,
    children = {},
  }

  if not entry.open then
    return table_node
  end

  local child_list = {}
  for name, child in pairs(node.children) do
    local child_entry = self.manager:get(child.value)
    table.insert(child_list, {
      name = name,
      node = child,
      is_dir = child_entry:isdir(),
    })
  end

  for _, item in ipairs(child_list) do
    table.insert(table_node.children, self:_totable(item.node))
  end

  return table_node
end

---@param lines string[]
---@param root_entry Entry
---@return table
function Files:_parse_lines(lines, root_entry)
  lines = util.filter_bl(lines)
  local parsed_tree_root = { ref_id = root_entry.ref_id, path = root_entry.path, children = {} }
  local parents = require("fyler.lib.structs.stack").new()
  parents:push { node = parsed_tree_root, indentation = -1 }

  for _, line in ipairs(lines) do
    local parser = require "fyler.views.finder.parser"
    local name = parser.parse_name(line)
    local ref_id = parser.parse_ref_id(line)
    local indent_level = parser.parse_indent_level(line)

    while true do
      local parent = parents:top()
      if not (parent.indentation >= indent_level and parents:size() > 1) then
        break
      end
      parents:pop()
    end

    local parent = parents:top()
    local node = {
      ref_id = ref_id,
      path = Path.new(parent.node.path):joinpath(name):abspath(),
      children = {},
    }
    parents:push { node = node, indentation = indent_level }
    parent.node.type = "directory"
    table.insert(parent.node.children, node)
  end

  return parsed_tree_root
end

---@param lines string[]
---@return table[]
function Files:diff_with_lines(lines)
  return require("fyler.views.finder.files.resolver")
    .new(self.root_path)
    :resolve(self, self:_parse_lines(lines, self.manager:get(self.trie.value)))
end

return Files
