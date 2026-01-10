local Path = require "fyler.lib.path"
local Trie = require "fyler.lib.structs.trie"
local helper = require "fyler.views.finder.helper"
local util = require "fyler.lib.util"

---@class ResolverNode
---@field create boolean|nil
---@field delete boolean|nil
---@field move string[]|nil
---@field copy string[]|nil
---@field entry_type string|nil

---@class Resolver
---@field trie Trie
---@field files Files
---@field parsed_buffer table
---@field old_ref_to_location table<integer, string>
---@field new_ref_to_location table<integer, string[]>
---@field processed_paths table<string, boolean>
local Resolver = {}
Resolver.__index = Resolver

---@param files Files
---@return Resolver
function Resolver.new(files)
  -- stylua: ignore start
  local instance = {
    trie                    = Trie.new(),
    files                   = files,
    new_ref_to_location     = {},
    old_ref_to_location     = {},
    processed_paths         = {},
  }
  -- stylua: ignore end

  setmetatable(instance, Resolver)

  return instance
end

---@return table
function Resolver:parse_and_save_buffer()
  local lines = util.filter_bl(vim.api.nvim_buf_get_lines(self.files.finder.win.bufnr, 0, -1, false))
  local root_entry = self.files.manager:get(self.files.trie.value)
  local parsed_tree_root = { ref_id = root_entry.ref_id, path = root_entry.path, children = {} }
  local parents = require("fyler.lib.structs.stack").new()
  parents:push { node = parsed_tree_root, indentation = -1 }

  for _, line in ipairs(lines) do
    local name = helper.parse_name(line)
    local ref_id = helper.parse_ref_id(line)
    local indent_level = helper.parse_indent_level(line)

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
      path = Path.new(parent.node.path):join(name):posix_path(),
      children = {},
    }

    parents:push { node = node, indentation = indent_level }
    parent.node.type = "directory"
    table.insert(parent.node.children, node)
  end

  self.parsed_buffer = parsed_tree_root

  return self
end

---@param path string
---@return string[]
function Resolver:path_to_segments(path)
  local posix_path = Path.new(path):posix_path()
  if not vim.startswith(posix_path, self.files.root_path) then
    local segments = vim.split(posix_path, "/")
    return util.filter_bl(segments)
  end
  local relative = posix_path:sub(#self.files.root_path + 1)
  if vim.startswith(relative, "/") then
    relative = relative:sub(2)
  end
  return util.filter_bl(vim.split(relative, "/"))
end

---@param segments string[]
---@return string
function Resolver:segments_to_path(segments)
  if #segments == 0 then
    return self.files.root_path
  end
  return self.files.root_path .. "/" .. table.concat(segments, "/")
end

---@param path string
---@param op_type "create"|"delete"|"move"|"copy"
---@param value boolean|string
---@param entry_type string|nil
function Resolver:mark_operation(path, op_type, value, entry_type)
  local path_obj = Path.new(path)
  local is_directory = path_obj:is_directory()
  local segments = self:path_to_segments(path_obj:posix_path())

  local node = self.trie:find(segments)
  if not node then
    node = self.trie:insert(segments, {})
  end

  if not node.value then
    node.value = {}
  end

  if op_type == "create" then
    node.value.create = true
    if entry_type then
      node.value.entry_type = entry_type
    elseif is_directory then
      node.value.entry_type = "directory"
    else
      node.value.entry_type = "file"
    end
  elseif op_type == "delete" then
    node.value.delete = true
  elseif op_type == "move" or op_type == "copy" then
    if not node.value[op_type] then
      node.value[op_type] = {}
    end
    if type(value) == "string" then
      table.insert(node.value[op_type], Path.new(value):posix_path())
    end
  end

  return self
end

function Resolver:mark_and_save_creates()
  local function traverse(node)
    if node.ref_id then
      if not self.new_ref_to_location[node.ref_id] then
        self.new_ref_to_location[node.ref_id] = {}
      end
      table.insert(self.new_ref_to_location[node.ref_id], Path.new(node.path):posix_path())
    else
      -- NOTE: It doesn't matter whether we mark a directory
      -- with children or not because `create` operation can
      -- handle intermediary directory so it is better leave it.
      local has_children = node.children and #node.children > 0
      if not has_children then
        self:mark_operation(
          Path.new(node.path):posix_path(),
          "create",
          true,
          Path.new(node.path):is_directory() and "directory" or "file"
        )
      end
    end

    for _, child in ipairs(node.children or {}) do
      traverse(child)
    end
  end

  traverse(self.parsed_buffer)

  return self
end

function Resolver:mark_and_save_deletes()
  local function traverse(node)
    local entry = self.files.manager:get(node.value)
    local posix_path = Path.new(entry.link or entry.path):posix_path()

    self.old_ref_to_location[node.value] = posix_path

    if not self.new_ref_to_location[node.value] then
      self:mark_operation(entry.link or entry.path, "delete", true)
    end

    if entry.open then
      for _, child in pairs(node.children) do
        traverse(child)
      end
    end
  end

  traverse(self.files.trie)

  return self
end

function Resolver:mark_moves_and_copies()
  local function process_operation(ref_id, paths)
    if not paths or #paths == 0 then
      return
    end

    local old_path = self.old_ref_to_location[ref_id]

    if #paths == 1 then
      if paths[1] == old_path then
        return
      end

      return self:mark_operation(old_path, "move", paths[1])
    elseif #paths > 1 then
      if util.if_any(paths, function(path)
        return path == old_path
      end) then
        util.tbl_each(paths, function(dest_path)
          if dest_path == old_path then
            return
          end

          self:mark_operation(old_path, "copy", dest_path)
        end)
      else
        for i = 1, #paths - 1 do
          self:mark_operation(old_path, "copy", paths[i])
        end

        self:mark_operation(old_path, "move", paths[#paths])
      end
    end
  end

  local function traverse(node)
    process_operation(node.value, self.new_ref_to_location[node.value])

    if self.files.manager:get(node.value).open then
      for _, child in pairs(node.children) do
        traverse(child)
      end
    end
  end

  traverse(self.files.trie)

  return self
end

---@return table[]
function Resolver:resolve()
  self:parse_and_save_buffer():mark_and_save_creates():mark_and_save_deletes():mark_moves_and_copies()

  local operations = {}
  self:traverse_and_collect(self.trie, operations, {})
  return operations
end

---@param node Trie
---@param operations table[]
---@param segments string[]
function Resolver:traverse_and_collect(node, operations, segments)
  local path = self:segments_to_path(segments)

  -- Jump to copy/move destinations first
  if node.value then
    if node.value.copy then
      for _, dst_path in ipairs(node.value.copy) do
        self:resolve_destination(dst_path, operations)
      end
    end

    if node.value.move then
      for _, dst_path in ipairs(node.value.move) do
        self:resolve_destination(dst_path, operations)
      end
    end
  end

  -- PRE-ORDER: Emit CREATE operations BEFORE processing children
  if not self.processed_paths[path] and node.value and node.value.create then
    self.processed_paths[path] = true
    self:emit_operations(node, path, operations)
  end

  -- Process children
  for name, child in pairs(node.children) do
    local child_segments = {}
    for i = 1, #segments do
      child_segments[i] = segments[i]
    end
    child_segments[#child_segments + 1] = name

    self:traverse_and_collect(child, operations, child_segments)
  end

  -- POST-ORDER: Emit MOVE/COPY/DELETE operations AFTER processing children
  if not self.processed_paths[path] then
    self.processed_paths[path] = true
    self:emit_operations(node, path, operations)
  end
end

---@param dst_path string
---@param operations table[]
function Resolver:resolve_destination(dst_path, operations)
  if self.processed_paths[dst_path] then
    return
  end

  local segments = self:path_to_segments(dst_path)
  local node = self.trie:find(segments)

  if node then
    self.processed_paths[dst_path] = true
    self:emit_operations(node, dst_path, operations)
  end
end

---@param node Trie
---@param path string
---@param operations table[]
function Resolver:emit_operations(node, path, operations)
  if not node.value then
    return
  end

  local ops = node.value

  -- Priority 1: COPY operations
  if ops.copy then
    for _, dst in ipairs(ops.copy) do
      table.insert(operations, { type = "copy", src = path, dst = dst })
    end
  end

  -- Priority 2: MOVE operations
  if ops.move then
    for _, dst in ipairs(ops.move) do
      table.insert(operations, { type = "move", src = path, dst = dst })
    end
  end

  -- Priority 3: DELETE
  if ops.delete then
    table.insert(operations, { type = "delete", path = path })
  end

  -- Priority 4: CREATE
  if ops.create then
    table.insert(operations, { type = "create", path = path, entry_type = ops.entry_type or "file" })
  end
end

return Resolver
