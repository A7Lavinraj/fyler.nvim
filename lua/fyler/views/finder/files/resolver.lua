local Path = require("fyler.lib.path")
local helper = require("fyler.views.finder.helper")
local manager = require("fyler.views.finder.files.manager")
local util = require("fyler.lib.util")

local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(files) return setmetatable({ files = files }, Resolver) end

function Resolver:resolve()
  local parsed_tree = self:_parse_buffer()
  local actions = self:_generate_actions(parsed_tree)
  actions = self:_filter_actions(actions)
  actions = self:_topsort_actions(actions)

  return actions
end

---@private
function Resolver:_parse_buffer()
  local root_entry = manager.get(self.files.trie.value)
  assert(root_entry, "Failed to get root entry from trie")

  local parsed_tree = {
    ref_id = root_entry.ref_id,
    path = root_entry.path,
    children = {},
  }

  local parent_stack = require("fyler.lib.structs.stack").new()
  parent_stack:push({ node = parsed_tree, indent = -1 })

  local buffer_lines = vim.api.nvim_buf_get_lines(self.files.finder.win.bufnr, 0, -1, false)

  for _, line in ipairs(util.filter_bl(buffer_lines)) do
    local entry_name = helper.parse_name(line)
    local entry_ref_id = helper.parse_ref_id(line)
    local entry_indent = helper.parse_indent_level(line)

    while parent_stack:size() > 1 and parent_stack:top().indent >= entry_indent do
      parent_stack:pop()
    end

    local current_parent = parent_stack:top()
    local parent_path = manager.get(current_parent.node.ref_id).path

    local child_node = {
      ref_id = entry_ref_id,
      path = Path.new(parent_path):join(entry_name):posix_path(),
    }

    current_parent.node.type = "directory"
    current_parent.node.children = current_parent.node.children or {}

    table.insert(current_parent.node.children, child_node)

    parent_stack:push({ node = child_node, indent = entry_indent })
  end

  return parsed_tree
end

---@private
function Resolver:_generate_actions(parsed_tree)
  local old_ref = {}
  local new_ref = {}
  local actions = {}

  local function traverse(node, should_continue)
    if should_continue(node) then
      for _, child_node in pairs(node.children or {}) do
        traverse(child_node, should_continue)
      end
    end
  end

  traverse(self.files.trie, function(node)
    local node_entry = assert(manager.get(node.value), "Unexpected nil node entry")

    if node_entry.link then
      old_ref[node.value] = node_entry.link
    else
      old_ref[node.value] = assert(node_entry.path, "Unexpected nil node entry path")
    end

    return node_entry.open
  end)

  traverse(parsed_tree, function(node)
    if not node.ref_id then
      table.insert(actions, { type = "create", path = node.path })
    else
      new_ref[node.ref_id] = new_ref[node.ref_id] or {}
      table.insert(new_ref[node.ref_id], node.path)
    end
    return true
  end)

  local function insert_action(ref_id, old_path)
    local dst_paths = new_ref[ref_id]

    if not dst_paths then
      table.insert(actions, { type = "delete", path = old_path })
      return
    end

    if #dst_paths == 1 then
      if dst_paths[1] ~= old_path then table.insert(actions, { type = "move", src = old_path, dst = dst_paths[1] }) end
      return
    end

    if util.if_any(dst_paths, function(path) return path == old_path end) then
      util.tbl_each(dst_paths, function(path)
        if path ~= old_path then table.insert(actions, { type = "copy", src = old_path, dst = path }) end
      end)
    else
      table.insert(actions, { type = "move", src = old_path, dst = dst_paths[1] })
      for i = 2, #dst_paths do
        table.insert(actions, { type = "copy", src = dst_paths[1], dst = dst_paths[i] })
      end
    end
  end

  for ref_id, original_path in pairs(old_ref) do
    insert_action(ref_id, original_path)
  end

  return actions
end

---@private
function Resolver:_filter_actions(actions)
  local seen_actions = {}

  local function create_action_key(action)
    if vim.list_contains({ "create", "delete" }, action.type) then
      return action.type .. ":" .. action.path
    elseif vim.list_contains({ "move", "copy" }, action.type) then
      return action.type .. ":" .. action.src .. "," .. action.dst
    else
      error(string.format("Unexpected action type: %s", action.type))
    end
  end

  return util.tbl_filter(actions, function(action)
    local action_key = create_action_key(action)

    if seen_actions[action_key] then
      return false
    else
      seen_actions[action_key] = true
    end

    if action.type == "move" or action.type == "copy" then return action.src ~= action.dst end

    return true
  end)
end

---@private
function Resolver:_topsort_actions(actions)
  if #actions == 0 then return actions end

  local Path = require("fyler.lib.path")
  local Trie = require("fyler.lib.structs.trie")

  local temp_paths = {}

  local function build_conflict_graph(action_list)
    local conflicts = {}

    for i = 1, #action_list do
      conflicts[i] = {}
    end

    for i = 1, #action_list do
      local action_i = action_list[i]

      for j = i + 1, #action_list do
        local action_j = action_list[j]

        if action_i.type == "move" and action_j.type == "move" then
          if action_i.src == action_j.dst and action_i.dst == action_j.src then
            table.insert(conflicts[i], j)
            table.insert(conflicts[j], i)
          end
        end
      end
    end

    return conflicts
  end

  local function expand_swaps(action_list)
    local conflicts = build_conflict_graph(action_list)
    local expanded = {}
    local processed = {}

    for i = 1, #action_list do
      if not processed[i] then
        local action = action_list[i]

        local swap_partner = nil
        for _, j in ipairs(conflicts[i]) do
          if not processed[j] then
            swap_partner = j
            break
          end
        end

        if swap_partner then
          local action_a = action_list[i]
          local action_b = action_list[swap_partner]
          local tmp_path = string.format("%s_temp_%05d", action_a.src, math.random(99999))

          temp_paths[tmp_path] = true

          table.insert(expanded, { type = "move", src = action_a.src, dst = tmp_path })
          table.insert(expanded, { type = "move", src = action_b.src, dst = action_b.dst })
          table.insert(expanded, { type = "move", src = tmp_path, dst = action_a.dst })

          processed[i] = true
          processed[swap_partner] = true
        else
          table.insert(expanded, action)
          processed[i] = true
        end
      end
    end

    return expanded
  end

  actions = expand_swaps(actions)

  local function build_dependency_graph(action_list)
    local src_trie = Trie.new()
    local dst_trie = Trie.new()

    local action_to_index = {}
    for i, action in ipairs(action_list) do
      action_to_index[action] = i
    end

    for _, action in ipairs(action_list) do
      local function append(existing_actions) return vim.list_extend(existing_actions or {}, { action }) end

      if action.type == "create" then
        dst_trie:insert(Path.new(action.path):segments(), append)
      elseif action.type == "delete" then
        src_trie:insert(Path.new(action.path):segments(), append)
      else
        src_trie:insert(Path.new(action.src):segments(), append)
        dst_trie:insert(Path.new(action.dst):segments(), append)
      end
    end

    local function collect_parent_actions(trie, target_path, collected_actions)
      local path_segments = Path.new(target_path):segments()
      local ancestor_nodes = { trie }

      for _, segment in ipairs(path_segments) do
        local current_node = ancestor_nodes[#ancestor_nodes]
        if not current_node or not current_node.children then return end

        local child_node = current_node.children[segment]
        if not child_node then return end

        table.insert(ancestor_nodes, child_node)
      end

      table.remove(ancestor_nodes)

      while #ancestor_nodes > 0 do
        local ancestor = ancestor_nodes[#ancestor_nodes]
        if ancestor.value and #ancestor.value > 0 then
          vim.list_extend(collected_actions, ancestor.value)
          break
        end

        table.remove(ancestor_nodes)
      end
    end

    local function collect_descendant_actions(trie, target_path, collected_actions, action_filter)
      local path_segments = Path.new(target_path):segments()
      local target_node = trie:find(path_segments)

      if not target_node then return end

      for _, child_node in pairs(target_node.children) do
        child_node:dfs(function(node)
          if node.value then
            if action_filter then
              for _, action in ipairs(node.value) do
                if action_filter(action) then table.insert(collected_actions, action) end
              end
            else
              vim.list_extend(collected_actions, node.value)
            end
          end
        end)
      end
    end

    local function collect_actions_at_path(trie, target_path, collected_actions, action_filter)
      local path_segments = Path.new(target_path):segments()
      local target_node = trie:find(path_segments)

      if target_node and target_node.value then
        for _, action in ipairs(target_node.value) do
          if not action_filter or action_filter(action) then table.insert(collected_actions, action) end
        end
      end
    end

    local function action_dependencies(action_index)
      local action = action_list[action_index]
      local function is_destructive_action(op) return op.type == "move" or op.type == "delete" end

      local dependencies = {}

      if action.type == "delete" then
        collect_descendant_actions(src_trie, action.path, dependencies)
      elseif action.type == "create" then
        collect_parent_actions(dst_trie, action.path, dependencies)
        if not temp_paths[action.path] then
          collect_actions_at_path(src_trie, action.path, dependencies, is_destructive_action)
        end
      elseif action.type == "move" then
        collect_parent_actions(dst_trie, action.dst, dependencies)
        collect_descendant_actions(src_trie, action.src, dependencies)
        if not temp_paths[action.dst] then
          collect_actions_at_path(src_trie, action.dst, dependencies, is_destructive_action)
        end
      elseif action.type == "copy" then
        collect_parent_actions(dst_trie, action.dst, dependencies)
        if not temp_paths[action.dst] then
          collect_actions_at_path(src_trie, action.dst, dependencies, is_destructive_action)
        end
      end

      local filtered_deps = {}
      for _, dep in ipairs(dependencies) do
        local dep_index = action_to_index[dep]
        if dep_index and dep_index ~= action_index then table.insert(filtered_deps, dep) end
      end

      return filtered_deps
    end

    local indegree = {}
    local graph = {}

    for i = 1, #action_list do
      indegree[i] = 0
      graph[i] = {}
    end

    for i = 1, #action_list do
      local dependencies = action_dependencies(i)
      for _, dep in ipairs(dependencies) do
        local dep_index = action_to_index[dep]
        if dep_index then
          table.insert(graph[dep_index], i)
          indegree[i] = indegree[i] + 1
        end
      end
    end

    return graph, indegree, action_list
  end

  local graph, indegree, final_actions = build_dependency_graph(actions)

  local ready_actions = {}
  for i = 1, #final_actions do
    if indegree[i] == 0 then table.insert(ready_actions, i) end
  end

  local topsorted = {}
  while #ready_actions > 0 do
    local current_index = table.remove(ready_actions, 1)
    table.insert(topsorted, final_actions[current_index])

    for _, dependent_index in ipairs(graph[current_index]) do
      indegree[dependent_index] = indegree[dependent_index] - 1
      if indegree[dependent_index] == 0 then table.insert(ready_actions, dependent_index) end
    end
  end

  if #topsorted ~= #final_actions then
    error(string.format("Circular dependency detected in actions: sorted %d of %d actions", #topsorted, #final_actions))
  end

  return topsorted
end

return Resolver
