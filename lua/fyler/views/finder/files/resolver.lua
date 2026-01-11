local Path = require "fyler.lib.path"
local helper = require "fyler.views.finder.helper"
local util = require "fyler.lib.util"

---@class Resolver
---@field files Files
local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(files)
  return setmetatable({ files = files }, Resolver)
end

---@return Resolver
function Resolver:parse_buffer()
  local lines = util.filter_bl(vim.api.nvim_buf_get_lines(self.files.finder.win.bufnr, 0, -1, false))
  local root_entry = self.files.manager:get(self.files.trie.value)
  local parsed_buffer = { ref_id = root_entry.ref_id, path = root_entry.path, children = {} }

  local parents = require("fyler.lib.structs.stack").new()
  parents:push { node = parsed_buffer, indentation = -1 }

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

  self.parsed_buffer = parsed_buffer

  return self
end

---@return Resolver
function Resolver:parse_actions()
  self.old_ref = {}
  self.new_ref = {}
  self.raw_act = {}

  ---@param node table
  local function traverse_tree(node, fn)
    if fn(node) then
      for _, child in pairs(node.children or {}) do
        traverse_tree(child, fn)
      end
    end
  end

  traverse_tree(self.files.trie, function(node)
    local node_entry = assert(self.files.manager:get(node.value), "Unexpected nil node entry")
    self.old_ref[node.value] = node_entry.link or node_entry.path
    return node_entry.open
  end)

  traverse_tree(self.parsed_buffer, function(node)
    if not node.ref_id then
      table.insert(self.raw_act, { type = "create", path = node.path })
    else
      self.new_ref[node.ref_id] = self.new_ref[node.ref_id] or {}
      table.insert(self.new_ref[node.ref_id], node.path)
    end
    return true
  end)

  for ref_id, path in pairs(self.old_ref) do
    if not self.new_ref[ref_id] then
      table.insert(self.raw_act, { type = "delete", path = path })
    end
  end

  for ref_id, old_path in pairs(self.old_ref) do
    (function()
      local paths = self.new_ref[ref_id]
      if not paths or #paths == 0 then
        return
      end

      if #paths == 1 then
        table.insert(self.raw_act, { type = "move", src = old_path, dst = paths[1] })
        return
      end

      if util.if_any(paths, function(path)
        return path == old_path
      end) then
        util.tbl_each(
          util.tbl_filter(paths, function(path)
            return not (path == old_path)
          end),
          function(path)
            table.insert(self.raw_act, { type = "copy", src = old_path, dst = path })
          end
        )
      else
        for i = 1, #paths - 1 do
          table.insert(self.raw_act, { type = "copy", src = old_path, dst = paths[i] })
        end
        table.insert(self.raw_act, { type = "move", src = old_path, dst = paths[#paths] })
      end
    end)()
  end

  return self
end

local function is_automatic_child_move(child_act, parent_act)
  if child_act.type ~= "move" or parent_act.type ~= "move" then
    return false
  end
  if not Path.new(child_act.src):is_descendant_of(parent_act.src) then
    return false
  end
  return child_act.dst == Path.new(parent_act.dst):join(Path.new(parent_act.src):relative(child_act.src)):posix_path()
end

local function transform_child_after_parent_move(child_act, parent_act)
  if child_act.type == "move" and parent_act.type == "move" then
    if Path.new(child_act.src):is_descendant_of(parent_act.src) then
      return {
        type = child_act.type,
        src = Path.new(parent_act.dst):join(Path.new(parent_act.src):relative(child_act.src)):posix_path(),
        dst = child_act.dst,
      }
    end
  end
  return child_act
end

function Resolver:final_actions()
  local filtered = {}
  local seen = {}

  for _, act in ipairs(self.raw_act) do
    (function()
      if (act.type == "move" or act.type == "copy") and act.src == act.dst then
        return
      end

      local key = act.type .. ":" .. (act.path or (act.src .. ">" .. act.dst))
      if seen[key] then
        return
      end
      seen[key] = true

      table.insert(filtered, act)
    end)()
  end

  local pruned = {}
  for _, act in ipairs(filtered) do
    local is_redundant = false

    for j = 1, #pruned do
      local prev = pruned[j]

      if is_automatic_child_move(act, prev) then
        is_redundant = true
        break
      end

      if prev.type == "delete" then
        local prev_path = prev.path
        local curr_src = act.src or act.path

        if curr_src and Path.new(curr_src):is_descendant_of(prev_path) then
          is_redundant = true
          break
        end
      end
    end

    if not is_redundant then
      table.insert(pruned, act)
    end
  end

  local transformed = {}
  for i, act in ipairs(pruned) do
    local transformed_act = act

    for j = 1, i - 1 do
      transformed_act = transform_child_after_parent_move(transformed_act, pruned[j])
    end

    table.insert(transformed, transformed_act)
  end

  local graph = {}
  local in_degree = {}

  for i = 1, #transformed do
    graph[i] = {}
    in_degree[i] = 0
  end

  for i = 1, #transformed do
    local act = transformed[i]

    if act.src then
      for j = 1, i - 1 do
        local prev = transformed[j]
        local prev_writes_to = prev.dst or prev.path

        if prev_writes_to == act.src then
          table.insert(graph[j], i)
          in_degree[i] = in_degree[i] + 1
        end
      end
    end
  end

  local queue = {}
  for i = 1, #transformed do
    if in_degree[i] == 0 then
      table.insert(queue, i)
    end
  end

  local result = {}
  while #queue > 0 do
    local idx = table.remove(queue, 1)
    table.insert(result, transformed[idx])

    for _, neighbor in ipairs(graph[idx]) do
      in_degree[neighbor] = in_degree[neighbor] - 1
      if in_degree[neighbor] == 0 then
        table.insert(queue, neighbor)
      end
    end
  end

  return result
end

---@return table
function Resolver:resolve()
  return self:parse_buffer():parse_actions():final_actions()
end

return Resolver
