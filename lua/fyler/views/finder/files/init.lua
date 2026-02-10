local Path = require("fyler.lib.path")
local Trie = require("fyler.lib.structs.trie")
local fs = require("fyler.lib.fs")
local manager = require("fyler.views.finder.files.manager")
local util = require("fyler.lib.util")

---@class Files
---@field trie Trie
---@field root_path string
---@field finder Finder
local Files = {}
Files.__index = Files

---@param opts table
---@return Files
function Files.new(opts)
  assert(Path.new(opts.path):is_directory(), "Files root must be a directory")

  local instance = {
    root_path = opts.path,
    finder = opts.finder,
    trie = Trie.new(manager.set({
      name = opts.name,
      open = opts.open,
      path = opts.path,
      type = "directory",
      updated = false,
    })),
  }

  local root_entry = manager.get(instance.trie.value)
  if root_entry.open then instance.finder.watcher:start(root_entry.path) end

  setmetatable(instance, Files)

  return instance
end

---@param path string
---@return string[]|nil
function Files:path_to_segments(path)
  local posix_path = Path.new(path):posix_path()
  if not vim.startswith(posix_path, self.root_path) then return nil end

  local relative = posix_path:sub(#self.root_path + 1)
  if relative:sub(1, 1) == "/" then relative = relative:sub(2) end

  return util.filter_bl(vim.split(relative, "/"))
end

---@param ref_id integer
---@return FilesEntry
function Files:node_entry(ref_id) return manager.get(assert(ref_id, "cannot find node without ref_id")) end

---@param ref_id integer
---@return Trie|nil
function Files:find_node_by_ref_id(ref_id)
  local entry = manager.get(ref_id)
  local segments = self:path_to_segments(entry.link or entry.path)
  if not segments then return nil end
  return self.trie:find(segments)
end

---@param ref_id integer
function Files:expand_node(ref_id)
  local entry = manager.get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")

  if entry.type ~= "directory" then return self end

  entry.open = true
  self.finder.watcher:start(entry.path)

  return self
end

---@param ref_id integer
function Files:collapse_node(ref_id)
  local entry = manager.get(ref_id)
  assert(entry, "cannot locate entry with given ref_id")

  if entry.type ~= "directory" then return self end

  entry.open = false
  self.finder.watcher:stop(entry.path)

  return self
end

---@param ref_id integer
---@return integer|nil
function Files:find_parent(ref_id)
  local entry = manager.get(ref_id)
  local segments = self:path_to_segments(entry.link or entry.path)

  if not segments or #segments == 0 then return nil end

  local parent_segments = {}
  for i = 1, #segments - 1 do
    parent_segments[i] = segments[i]
  end

  if #parent_segments == 0 then return self.trie.value end

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
  local entry = manager.get(node.value)

  if entry.type == "directory" and entry.open then
    entry.open = false
    self.finder.watcher:stop(entry.path)
  end

  for _, child in pairs(node.children) do
    self:_collapse_recursive(child)
  end
end

---@param parent_ref_id integer
---@param opts FilesEntryOpts
function Files:add_child(parent_ref_id, opts)
  local parent_entry = manager.get(parent_ref_id)

  opts.path = Path.new(parent_entry.link or parent_entry.path):join(opts.name):posix_path()

  local child_ref_id = manager.set(opts)

  local parent_segments = self:path_to_segments(parent_entry.link or parent_entry.path)
  local parent_node = self.trie:find(parent_segments or {})

  if parent_node then parent_node.children[opts.name] = Trie.new(child_ref_id) end
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

  if not onupdate then error("callback function is required") end

  local node = ref_id and self:find_node_by_ref_id(ref_id) or self.trie

  self:_update(node, function(err)
    if err then return onupdate(err) end

    onupdate(nil, self)
  end)
end

---@param node Trie
---@param onupdate function
function Files:_update(node, onupdate)
  local node_entry = manager.get(node.value)
  if not node_entry.open then return onupdate(nil) end

  fs.ls({
    path = Path.new(node_entry.link or node_entry.path):os_path(),
  }, function(err, entries)
    if err or not entries then return onupdate(err) end

    local entry_paths = {}
    for _, entry in ipairs(entries) do
      entry_paths[entry.name] = entry
    end

    for name, child_node in pairs(node.children) do
      if not entry_paths[name] then
        local child_entry = manager.get(child_node.value)
        if child_entry.type == "directory" then self.finder.watcher:stop(child_entry.path) end
        node.children[name] = nil
      end
    end

    for name, entry in pairs(entry_paths) do
      if not node.children[name] then
        local child_ref_id = manager.set(entry)
        local child_node = Trie.new(child_ref_id)
        node.children[name] = child_node

        local child_entry = manager.get(child_ref_id)
        if child_entry.type == "directory" and child_entry.open then self.finder.watcher:start(child_entry.path) end
      end
    end

    node_entry.updated = true

    local children_list = {}
    for _, child in pairs(node.children) do
      table.insert(children_list, child)
    end

    local function update_next(index)
      if index > #children_list then return onupdate(nil) end

      self:_update(children_list[index], function(err)
        if err then return onupdate(err) end
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
  if not segments then return onnavigate(nil, nil, false) end

  if #segments == 0 then return onnavigate(nil, self.trie.value, false) end

  local did_update = false

  local function process_segment(index, current_node)
    if index > #segments then return onnavigate(nil, current_node.value, did_update) end

    local segment = segments[index]
    local current_entry = manager.get(current_node.value)

    if current_entry.type == "directory" then
      local needs_update = not current_entry.open or not current_entry.updated

      if needs_update then
        did_update = true
        self:expand_node(current_node.value):update(current_node.value, function(err)
          if err then return onnavigate(err, nil, did_update) end

          local next_node = current_node.children[segment]
          if not next_node then return onnavigate(nil, nil, did_update) end

          process_segment(index + 1, next_node)
        end)
      else
        local next_node = current_node.children[segment]
        if not next_node then return onnavigate(nil, nil, did_update) end

        process_segment(index + 1, next_node)
      end
    else
      return onnavigate(nil, nil, did_update)
    end
  end

  process_segment(1, self.trie)
end

---@return table
function Files:totable() return self:_totable(self.trie) end

---@param node Trie
---@return table
function Files:_totable(node)
  local entry = manager.get(node.value)
  local table_node = {
    link = entry.link,
    name = entry.name,
    open = entry.open,
    path = entry.path,
    ref_id = node.value,
    type = entry.type,
    children = {},
  }

  if not entry.open then return table_node end

  local child_list = {}
  for name, child in pairs(node.children) do
    local child_entry = manager.get(child.value)
    table.insert(child_list, { name = name, node = child, is_dir = child_entry.type == "directory" })
  end

  for _, item in ipairs(child_list) do
    table.insert(table_node.children, self:_totable(item.node))
  end

  return table_node
end

---@return table[]
function Files:diff_with_buffer() return require("fyler.views.finder.files.resolver").new(self):resolve() end

return Files
