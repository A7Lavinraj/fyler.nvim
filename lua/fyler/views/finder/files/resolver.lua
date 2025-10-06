local Path = require "fyler.lib.path"
local Trie = require "fyler.lib.structs.trie"
local util = require "fyler.lib.util"

---@class ResolverNode
---@field create boolean|nil
---@field delete boolean|nil
---@field move string[]|nil
---@field copy string[]|nil
---@field entry_type string|nil

---@class Resolver
---@field trie Trie
---@field processed table<string, boolean>
---@field root_path string
local Resolver = {}
Resolver.__index = Resolver

---@param root_path string
---@return Resolver
function Resolver.new(root_path)
  local instance = {
    trie = Trie.new(),
    processed = {},
    root_path = root_path,
  }
  setmetatable(instance, Resolver)
  return instance
end

---@param path string
---@return string[]
function Resolver:path_to_segments(path)
  local normalized = Path.new(path):norm():abspath()

  if not vim.startswith(normalized, self.root_path) then
    local segments = vim.split(normalized, "/")
    return util.filter_bl(segments)
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

---@param segments string[]
---@return string
function Resolver:segments_to_path(segments)
  if #segments == 0 then
    return self.root_path
  end
  return self.root_path .. "/" .. table.concat(segments, "/")
end

---@param path string
---@param op_type "create"|"delete"|"move"|"copy"
---@param value boolean|string
---@param entry_type string|nil
function Resolver:mark_operation(path, op_type, value, entry_type)
  local path_obj = Path.new(path)
  local is_dir = path_obj:is_dir()
  local normalized = path_obj:norm():abspath()

  local segments = self:path_to_segments(normalized)
  local node = self.trie:find(segments)

  if not node then
    node = self.trie:insert(segments, {})
  end

  if not node.value then
    node.value = {}
  end

  if op_type == "create" then
    node.value.create = true
    node.value.entry_type = entry_type or (is_dir and "directory" or "file")
  elseif op_type == "delete" then
    node.value.delete = true
  elseif op_type == "move" or op_type == "copy" then
    if not node.value[op_type] then
      node.value[op_type] = {}
    end
    -- value is a string (destination path) for move/copy
    if type(value) == "string" then
      local dest_normalized = Path.new(value):norm():abspath()
      table.insert(node.value[op_type], dest_normalized)
    end
  end
end

---@param parsed_tree table
---@return table<integer, string[]>
function Resolver:analyze_and_mark_creates(parsed_tree)
  local ref_id_locations = {}

  local function traverse(node)
    if node.ref_id then
      if not ref_id_locations[node.ref_id] then
        ref_id_locations[node.ref_id] = {}
      end
      -- Normalize path before storing
      local normalized = Path.new(node.path):norm():abspath()
      table.insert(ref_id_locations[node.ref_id], normalized)
    else
      local has_children = node.children and #node.children > 0
      if not has_children then
        -- Detect type from original path (before normalization)
        local entry_type = Path.new(node.path):is_dir() and "directory" or "file"
        self:mark_operation(node.path, "create", true, entry_type)
      end
    end

    for _, child in ipairs(node.children or {}) do
      traverse(child)
    end
  end

  traverse(parsed_tree)
  return ref_id_locations
end

---@param files Files
---@param ref_id_locations table<integer, string[]>
---@return table<integer, string>
function Resolver:mark_deletes_and_track_current(files, ref_id_locations)
  local current_ref_to_path = {}

  local function traverse(node)
    local entry = files.manager:get(node.value)
    local normalized = Path.new(entry.path):norm():abspath()
    current_ref_to_path[node.value] = normalized

    if not ref_id_locations[node.value] then
      self:mark_operation(entry.path, "delete", true)
    end

    if not entry.open then
      return
    end

    for _, child in pairs(node.children) do
      traverse(child)
    end
  end

  traverse(files.trie)
  return current_ref_to_path
end

---@param ref_id_locations table<integer, string[]>
---@param current_ref_to_path table<integer, string>
function Resolver:mark_moves_and_copies(ref_id_locations, current_ref_to_path)
  for ref_id, parsed_paths in pairs(ref_id_locations) do
    local current_path = current_ref_to_path[ref_id]

    if current_path then
      if #parsed_paths == 1 then
        if parsed_paths[1] ~= current_path then
          self:mark_operation(current_path, "move", parsed_paths[1])
        end
      elseif #parsed_paths > 1 then
        local current_in_destinations = util.if_any(parsed_paths, function(p)
          return p == current_path
        end)

        if current_in_destinations then
          for _, dest_path in ipairs(parsed_paths) do
            if dest_path ~= current_path then
              self:mark_operation(current_path, "copy", dest_path)
            end
          end
        else
          self:mark_operation(current_path, "move", parsed_paths[1])
          for i = 2, #parsed_paths do
            self:mark_operation(current_path, "copy", parsed_paths[i])
          end
        end
      end
    end
  end
end

---@param files Files
---@param parsed_tree table
---@return table[]
function Resolver:resolve(files, parsed_tree)
  local ref_id_locations = self:analyze_and_mark_creates(parsed_tree)

  local current_ref_to_path = self:mark_deletes_and_track_current(files, ref_id_locations)

  self:mark_moves_and_copies(ref_id_locations, current_ref_to_path)

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
  if not self.processed[path] and node.value and node.value.create then
    self.processed[path] = true
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
  if not self.processed[path] then
    self.processed[path] = true
    self:emit_operations(node, path, operations)
  end
end

---@param dst_path string
---@param operations table[]
function Resolver:resolve_destination(dst_path, operations)
  if self.processed[dst_path] then
    return
  end

  local segments = self:path_to_segments(dst_path)
  local node = self.trie:find(segments)

  if node then
    self.processed[dst_path] = true
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
