local Path = require("fyler.lib.path")
local helper = require("fyler.views.finder.helper")
local manager = require("fyler.views.finder.files.manager")
local util = require("fyler.lib.util")

local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(files) return setmetatable({ files = files }, Resolver) end

function Resolver:parsing()
  local root_entry = manager.get(self.files.trie.value)
  self.parsed_buffer = { ref_id = root_entry.ref_id, path = root_entry.path, children = {} }

  local parents = require("fyler.lib.structs.stack").new()
  parents:push({ node = self.parsed_buffer, indent = -1 })

  for _, line in ipairs(util.filter_bl(vim.api.nvim_buf_get_lines(self.files.finder.win.bufnr, 0, -1, false))) do
    local name = helper.parse_name(line)
    local ref_id = helper.parse_ref_id(line)
    local indent = helper.parse_indent_level(line)

    while parents:size() > 1 and parents:top().indent >= indent do
      parents:pop()
    end

    local parent = parents:top()
    local node = {}

    node.ref_id = ref_id
    node.path = Path.new(manager.get(parent.node.ref_id).path):join(name):posix_path()

    parent.node.type = "directory"
    parent.node.children = parent.node.children or {}
    table.insert(parent.node.children, node)
    parents:push({ node = node, indent = indent })
  end

  return self
end

function Resolver:generate()
  local old_ref = {}
  local new_ref = {}

  self.actions = {}

  local function traverse_tree(node, fn)
    if fn(node) then
      for _, child_node in pairs(node.children or {}) do
        traverse_tree(child_node, fn)
      end
    end
  end

  traverse_tree(self.files.trie, function(node)
    local node_entry = assert(manager.get(node.value), "Unexpected nil node entry")
    if node_entry.link then
      old_ref[node.value] = node_entry.link
    else
      old_ref[node.value] = assert(node_entry.path, "Unexpected nil node entry path")
    end
    return node_entry.open
  end)

  traverse_tree(self.parsed_buffer, function(node)
    if not node.ref_id then
      table.insert(self.actions, { type = "create", path = node.path })
    else
      new_ref[node.ref_id] = new_ref[node.ref_id] or {}
      table.insert(new_ref[node.ref_id], node.path)
    end
    return true
  end)

  local function insert_action(ref_id, old_path)
    local paths = new_ref[ref_id]
    if not paths then
      table.insert(self.actions, { type = "delete", path = old_path })
      return
    end

    if #paths == 1 then
      table.insert(self.actions, { type = "move", src = old_path, dst = paths[1] })
      return
    end

    if util.if_any(paths, function(path) return path == old_path end) then
      util.tbl_each(paths, function(path)
        if path ~= old_path then table.insert(self.actions, { type = "copy", src = old_path, dst = path }) end
      end)
    else
      table.insert(self.actions, { type = "move", src = old_path, dst = paths[1] })
      for i = 2, #paths do
        table.insert(self.actions, { type = "copy", src = old_path, dst = paths[i] })
      end
    end
  end

  for ref_id, old_path in pairs(old_ref) do
    insert_action(ref_id, old_path)
  end

  return self
end

function Resolver:filters()
  local seen_creates = {}
  local seen_sources = {}
  local seen_destinations = {}

  self.filtered_actions = util.tbl_filter(self.actions, function(d)
    if d.type == "create" then
      if seen_sources[d.path] then return false end

      if seen_creates[d.path] then return false end

      seen_creates[d.path] = true

      return true
    elseif d.type == "move" or d.type == "copy" then
      if d.src == d.dst then return false end

      if d.type == "move" and seen_sources[d.src] then return false end

      if seen_destinations[d.dst] then return false end

      if seen_creates[d.dst] then return false end

      for _, other in ipairs(self.actions) do
        if other.type == "delete" and other.path == d.src then return false end
      end

      seen_sources[d.src] = true
      seen_destinations[d.dst] = true
      return true
    elseif d.type == "delete" then
      if seen_creates[d.path] then return false end

      if seen_sources[d.path] then return false end

      if seen_destinations[d.path] then return false end

      return true
    end

    return false
  end)

  return self
end

function Resolver:topsort()
  local filtered_actions = self.filtered_actions
  local n = #filtered_actions

  if n == 0 then
    self.sorted_actions = {}
    return {}
  end

  local graph = {}
  local indegree = {}

  for i = 1, n do
    graph[i] = {}
    indegree[i] = 0
  end

  for i = 1, n do
    for j = 1, n do
      if i ~= j then
        local action_a, action_b = filtered_actions[i], filtered_actions[j]

        if
          (action_a.type == "create" or action_a.type == "move" or action_a.type == "copy")
          and (action_b.type == "move" or action_b.type == "copy")
        then
          local dst_i = action_a.type == "create" and action_a.path or action_a.dst
          local src_j = action_b.src

          if dst_i and src_j and Path.new(dst_i) == Path.new(src_j) then
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end

        if (action_a.type == "move" or action_a.type == "copy") and action_b.type == "delete" then
          if Path.new(action_a.src) == Path.new(action_b.path) then
            -- i must happen before j
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end

        if action_a.type == "move" and action_b.type == "move" then
          if Path.new(action_a.src) == Path.new(action_b.dst) then
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end

        if action_a.type == "create" and action_b.type == "delete" then
          if Path.new(action_a.path) == Path.new(action_b.path) then
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end

        if action_a.type == "move" and action_b.type == "delete" then
          if Path.new(action_a.dst) == Path.new(action_b.path) then
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end

        if
          (action_a.type == "create" or action_a.type == "move" or action_a.type == "copy")
          and action_b.type == "copy"
        then
          local dst_i = action_a.type == "create" and action_a.path or action_a.dst
          local src_j = action_b.src

          if dst_i and src_j and Path.new(dst_i) == Path.new(src_j) then
            table.insert(graph[i], j)
            indegree[j] = indegree[j] + 1
          end
        end
      end
    end
  end

  local queue = {}
  local sorted = {}

  for i = 1, n do
    if indegree[i] == 0 then table.insert(queue, i) end
  end

  table.sort(queue)

  local processed = 0

  while #queue > 0 do
    local u = table.remove(queue, 1)
    table.insert(sorted, filtered_actions[u])
    processed = processed + 1

    for _, v in ipairs(graph[u]) do
      indegree[v] = indegree[v] - 1
      if indegree[v] == 0 then table.insert(queue, v) end
    end

    table.sort(queue)
  end

  assert(processed == n, "Cannot resolve operations: circular dependency detected!")

  return vim.iter(sorted):rev():totable()
end

function Resolver:resolve() return self:parsing():generate():filters():topsort() end

return Resolver
