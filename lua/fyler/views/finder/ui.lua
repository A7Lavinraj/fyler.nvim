local Ui = require "fyler.lib.ui"
local config = require "fyler.config"
local diagnostic = require "fyler.lib.diagnostic"
local git = require "fyler.lib.git"
local util = require "fyler.lib.util"

local Component = Ui.Component
local Text = Ui.Text
local Row = Ui.Row
local Column = Ui.Column

local function sort_nodes(nodes)
  table.sort(nodes, function(x, y)
    local x_is_dir = x.type == "directory"
    local y_is_dir = y.type == "directory"
    if x_is_dir and not y_is_dir then
      return true
    elseif not x_is_dir and y_is_dir then
      return false
    else
      local function pad_numbers(str)
        return str:gsub("%d+", function(n)
          return string.format("%010d", n)
        end)
      end
      return pad_numbers(x.name) < pad_numbers(y.name)
    end
  end)
  return nodes
end

local function flatten_tree(node, depth, result)
  depth = depth or 0
  result = result or {}

  if not node or not node.children then
    return result
  end

  local sorted_items = sort_nodes(node.children)
  for _, item in ipairs(sorted_items) do
    table.insert(result, { item = item, depth = depth })
    if item.children and #item.children > 0 then
      flatten_tree(item, depth + 1, result)
    end
  end

  return result
end

---@return string|nil, string|nil
local function icon_and_hl(item)
  local icon, hl = config.icon_provider(item.type, item.path)
  if config.values.integrations.icon == "none" then
    return icon, hl
  end

  if item.type == "directory" then
    local icons = config.values.views.finder.icon
    local is_empty = item.open and item.children and #item.children == 0
    local is_expanded = item.open or false
    icon = is_empty and icons.directory_empty
      or (is_expanded and icons.directory_expanded or icons.directory_collapsed)
      or icon
  end

  return icon, hl
end

local function create_column_context(tag, node, flattened_entries, files_column)
  return {
    tag = tag,
    root_dir = node.path,
    entries = flattened_entries,

    update_entry_highlight = function(index, highlight)
      local row = files_column[index]
      if row and row.children then
        local name_component = row.children[4]
        if name_component then
          name_component.option = name_component.option or {}
          name_component.option.highlight = highlight
        end
      end
    end,

    get_entry_data = function(index)
      local entry = flattened_entries[index]
      if not entry then
        return nil
      end

      return {
        path = entry.item.path,
        name = entry.item.name,
        type = entry.item.type,
        depth = entry.depth,
        ref_id = entry.item.ref_id,
        item = entry.item,
      }
    end,

    get_all_paths = function()
      return util.tbl_map(flattened_entries, function(entry)
        return entry.item.path
      end)
    end,

    get_files_column = function()
      return files_column
    end,
  }
end

local M = {}

M.tag = 0

local columns = {
  git = function(context, _, onbuild)
    git.map_entries_async(context.root_dir, context.get_all_paths(), function(entries)
      local highlights, column = {}, {}
      for i, get_entry in ipairs(entries) do
        highlights[i] = get_entry[2]
        table.insert(column, Text(nil, { virt_text = { get_entry } }))
      end

      for i, hl in pairs(highlights) do
        local entry_data = context.get_entry_data(i)
        if entry_data then
          local name_highlight = hl or ((entry_data.type == "directory") and "FylerFSDirectoryName" or nil)
          if name_highlight then
            context.update_entry_highlight(i, name_highlight)
          end
        end
      end

      -- IMPORTANT: If both tags are not equal then this render call doesn't belongs to any initiater
      -- and must be prevented from updating UI otherwise UI could get corrupted data.
      if M.tag == context.tag then
        onbuild(
          { tag = "files", children = { Row { Column(context.get_files_column()), Column(column) } } },
          { partial = true }
        )
      end
    end)
  end,

  diagnostic = function(context, _, onbuild)
    diagnostic.map_entries_async(context.root_dir, context.get_all_paths(), function(entries)
      local highlights, column = {}, {}
      for i, get_entry in ipairs(entries) do
        highlights[i] = get_entry[2]
        table.insert(column, Text(nil, { virt_text = { get_entry } }))
      end

      for i, hl in pairs(highlights) do
        local entry_data = context.get_entry_data(i)
        if entry_data then
          local name_highlight = hl or ((entry_data.type == "directory") and "FylerFSDirectoryName" or nil)
          if name_highlight then
            context.update_entry_highlight(i, name_highlight)
          end
        end
      end

      -- IMPORTANT: If both tags are not equal then this render call doesn't belongs to any initiater
      -- and must be prevented from updating UI otherwise UI could get corrupted data.
      if M.tag == context.tag then
        onbuild(
          { tag = "files", children = { Row { Column(context.get_files_column()), Column(column) } } },
          { partial = true }
        )
      end
    end)
  end,
}

M.files = Component.new_async(function(node, callback)
  M.tag = M.tag + 1

  if not node or not node.children then
    return callback { tag = "files", children = {} }
  end

  local flattened_entries = flatten_tree(node)
  if #flattened_entries == 0 then
    return callback { tag = "files", children = {} }
  end

  local files_column = {}
  for _, entry in ipairs(flattened_entries) do
    local item, depth = entry.item, entry.depth
    local icon, hl = icon_and_hl(item)
    local icon_highlight = (item.type == "directory") and "FylerFSDirectoryIcon" or hl
    local name_highlight = (item.type == "directory") and "FylerFSDirectoryName" or nil
    icon = icon and (icon .. "  ") or ""

    local indentation_text = Text(string.rep(" ", 2 * depth))
    local icon_text = Text(icon, { highlight = icon_highlight })
    local ref_id_text = item.ref_id and Text(string.format("/%05d ", item.ref_id)) or Text ""
    local name_text = Text(item.name, { highlight = name_highlight })
    table.insert(files_column, Row { indentation_text, icon_text, ref_id_text, name_text })
  end

  callback { tag = "files", children = { Row { Column(files_column) } } }

  for name, cfg in pairs(config.values.views.finder.columns) do
    local column = columns[name]
    if column and cfg.enabled then
      column(create_column_context(M.tag, node, flattened_entries, files_column), cfg, callback)
    end
  end
end)

M.operations = Component.new(function(operations)
  local types, details = {}, {}
  for _, operation in ipairs(operations) do
    if operation.type == "create" then
      table.insert(types, Text("CREATE", { highlight = "FylerGreen" }))
      table.insert(details, Text(operation.path))
    elseif operation.type == "delete" then
      table.insert(
        types,
        Text(config.values.views.finder.delete_to_trash and "TRASH" or "DELETE", { highlight = "FylerRed" })
      )
      table.insert(details, Text(operation.path))
    elseif operation.type == "move" then
      table.insert(types, Text("MOVE", { highlight = "FylerYellow" }))
      table.insert(details, Row { Text(operation.src), Text " > ", Text(operation.dst) })
    elseif operation.type == "copy" then
      table.insert(types, Text("COPY", { highlight = "FylerBlue" }))
      table.insert(details, Row { Text(operation.src), Text " > ", Text(operation.dst) })
    else
      error(string.format("Unknown operation type '%s'", operation.type))
    end
  end
  return { tag = "operations", children = { Row { Column(types), Text " ", Column(details) } } }
end)

return M
