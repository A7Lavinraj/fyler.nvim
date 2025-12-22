local Manager = require "fyler.views.finder.files.manager"
local Path = require "fyler.lib.path"
local Trie = require "fyler.lib.structs.trie"
local fs = require "fyler.lib.fs"
local util = require "fyler.lib.util"
local watcher = require "fyler.lib.watcher"

---@class Files
---@field trie Trie
---@field manager EntryManager
---@field root_path string
---@field finder Finder
local Files = {}
Files.__index = Files

---@param opts table
---@return Files
function Files.new(opts)
  assert(opts.type == "directory", "Files root must be a directory")

  local instance = {}
  instance.manager = Manager.new()
  instance.root_path = opts.path

  local ref_id = instance.manager:set(opts)
  instance.trie = Trie.new(ref_id)

  setmetatable(instance, Files)

  instance:_register_watcher(instance.trie, true)

  local path = Path.new(instance.root_path):join ".git"
  if path:exists() then
    watcher.register(path:normalize(), function(_, filename)
      if filename == "index" then
        instance.finder:dispatch_refresh { force_update = true }
      end
    end)
  end

  return instance
end

---@param path string
---@return string[]|nil
function Files:path_to_segments(path)
  local normalized = Path.new(path):normalize()

  if not vim.startswith(normalized, self.root_path) then
    return nil
  end

  local relative = normalized:sub(#self.root_path + 1)
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

---@param node Trie
---@param register_self boolean
function Files:_register_watcher(node, register_self)
  local entry = self.manager:get(node.value)
  if entry.path:match "%.git" then
    return
  end

  if register_self and entry:is_directory() then
    watcher.register(entry.path, function()
      self.finder:dispatch_refresh { force_update = true }
    end)
  end

  for _, child in pairs(node.children) do
    local child_entry = self.manager:get(child.value)
    if child_entry:is_directory() and child_entry.open then
      watcher.register(child_entry.path, function()
        self.finder:dispatch_refresh { force_update = true }
      end)
      self:_register_watcher(child, false)
    end
  end
end

---@param node Trie
---@param unregister_self boolean
function Files:_unregister_watcher(node, unregister_self)
  local entry = self.manager:get(node.value)
  if entry.path:match "%.git" then
    return
  end

  if unregister_self and entry:is_directory() then
    watcher.unregister(entry.path)
  end

  for _, child in pairs(node.children) do
    local child_entry = self.manager:get(child.value)
    if child_entry:is_directory() then
      watcher.unregister(child_entry.path)
      self:_unregister_watcher(child, false)
    end
  end
end

---@param ref_id integer
function Files:expand_node(ref_id)
  local entry = self.manager:get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")

  if not entry:is_directory() then
    return self
  end

  entry.open = true

  local node = self:find_node_by_ref_id(ref_id)
  if node then
    self:_register_watcher(node, true)
  end

  return self
end

---@param ref_id integer
function Files:collapse_node(ref_id)
  local entry = self.manager:get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")

  if not entry:is_directory() then
    return
  end

  entry.open = false

  local node = self:find_node_by_ref_id(ref_id)
  if node then
    self:_unregister_watcher(node, true)
  end
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
  if entry:is_directory() and entry.open then
    entry.open = false
    watcher.unregister(entry.path)
  end

  for _, child in pairs(node.children) do
    self:_collapse_recursive(child)
  end
end

---@param parent_ref_id integer
---@param opts EntryOpts
function Files:add_child(parent_ref_id, opts)
  local parent_entry = self.manager:get(parent_ref_id)

  opts.path = Path.new(parent_entry.path):join(opts.name):normalize()

  local child_ref_id = self.manager:set(opts)

  local parent_segments = self:path_to_segments(parent_entry.path)
  local parent_node = self.trie:find(parent_segments or {})

  if parent_node then
    parent_node.children[opts.name] = Trie.new(child_ref_id)
  end
end

---@param ... integer|function
function Files:update(...)
  local ref_id = nil
  local onupdate = nil

  for i = 1, select("#", ...) do
    local arg = select(i, ...)

    if type(arg) == "number" then
      ref_id = arg
    elseif type(arg) == "function" then
      onupdate = arg
    end
  end

  if not onupdate then
    error "callback function is required"
  end

  local node = ref_id and self:find_node_by_ref_id(ref_id) or self.trie

  self:_update(node, function(err)
    if err then
      return onupdate(err)
    end

    onupdate(nil, self)
  end)
end

---@param node Trie
---@param onupdate function
function Files:_update(node, onupdate)
  local node_entry = self.manager:get(node.value)
  if not node_entry.open then
    return onupdate(nil)
  end

  fs.ls(node_entry.path, function(err, entries)
    if err or not entries then
      return onupdate(err)
    end

    local entry_paths = {}
    for _, entry in ipairs(entries) do
      entry_paths[entry.name] = entry
    end

    -- Unregister removed children
    for name, child_node in pairs(node.children) do
      if not entry_paths[name] then
        local child_entry = self.manager:get(child_node.value)
        if child_entry:is_directory() then
          self:_unregister_watcher(child_node, true)
        end
        node.children[name] = nil
      end
    end

    -- Add new children
    for name, entry in pairs(entry_paths) do
      if not node.children[name] then
        local child_ref_id = self.manager:set(entry)
        local child_node = Trie.new(child_ref_id)
        node.children[name] = child_node

        local child_entry = self.manager:get(child_ref_id)
        if child_entry:is_directory() and child_entry.open then
          self:_register_watcher(child_node, true)
        end
      end
    end

    -- Mark as updated
    node_entry.updated = true

    -- Update children recursively
    local children_list = {}
    for _, child in pairs(node.children) do
      table.insert(children_list, child)
    end

    local function update_next(index)
      if index > #children_list then
        return onupdate(nil)
      end

      self:_update(children_list[index], function(err)
        if err then
          return onupdate(err)
        end
        update_next(index + 1)
      end)
    end

    update_next(1)
  end)
end

---@param path string
---@param onnavigate function
function Files:navigate(path, onnavigate)
  local segments = self:path_to_segments(path)
  if not segments then
    return onnavigate(nil, nil, false)
  end

  if #segments == 0 then
    return onnavigate(nil, self.trie.value, false)
  end

  local did_update = false

  local function process_segment(index, current_node)
    if index > #segments then
      return onnavigate(nil, current_node.value, did_update)
    end

    local segment = segments[index]
    local current_entry = self.manager:get(current_node.value)

    if current_entry:is_directory() then
      -- Check if node needs updating (not open OR not updated)
      local needs_update = not current_entry.open or not current_entry.updated

      if needs_update then
        did_update = true
        -- Expand and update the directory
        self:expand_node(current_node.value):update(current_node.value, function(err)
          if err then
            return onnavigate(err, nil, did_update)
          end

          local next_node = current_node.children[segment]
          if not next_node then
            return onnavigate(nil, nil, did_update)
          end

          process_segment(index + 1, next_node)
        end)
      else
        -- Node is already open and updated, skip update
        local next_node = current_node.children[segment]
        if not next_node then
          return onnavigate(nil, nil, did_update)
        end

        process_segment(index + 1, next_node)
      end
    else
      -- It's a file, can't navigate further
      return onnavigate(nil, nil, did_update)
    end
  end

  process_segment(1, self.trie)
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
      is_dir = child_entry:is_directory(),
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
    local name = util.parse_name(line)
    local ref_id = util.parse_ref_id(line)
    local indent_level = util.parse_indent_level(line)

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
      path = Path.new(parent.node.path):join(name):normalize(),
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
