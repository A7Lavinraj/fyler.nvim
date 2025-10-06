local Ui = require "fyler.lib.ui"
local config = require "fyler.config"
local Component = Ui.Component
local Text = Ui.Text
local Row = Ui.Row
local Column = Ui.Column

local icon_provider
if type(config.values.icon_provider) == "function" then
  icon_provider = config.values.icon_provider
else
  icon_provider = require("fyler.integrations.icon")[config.values.icon_provider]
end

local function isdir(node)
  return node.type == "directory"
end

local function sort_nodes(nodes)
  table.sort(nodes, function(x, y)
    local x_is_dir = isdir(x)
    local y_is_dir = isdir(y)
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

-- Flatten the tree into a list of file entries
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
  local icon, hl = icon_provider(item.type, item.path)

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

local function create_file_content(entry)
  local item, depth = entry.item, entry.depth
  local icon, hl = icon_and_hl(item)

  local icon_highlight, name_highlight
  if item.type == "directory" then
    icon_highlight = "FylerFSDirectoryIcon"
    name_highlight = "FylerFSDirectoryName"
  else
    icon_highlight = hl
  end

  if not not icon then
    icon = icon .. " "
  else
    icon = ""
  end

  local indentation_text = Text(string.rep(" ", 2 * depth))
  local icon_text = Text(icon, {
    highlight = icon_highlight,
  })

  local ref_id_text
  if item.ref_id then
    ref_id_text = Text(string.format("/%05d ", item.ref_id))
  else
    ref_id_text = Text ""
  end

  local name_text = Text(item.name, {
    highlight = name_highlight,
  })

  -- Return Row of Text components for proper highlighting
  return Row { indentation_text, icon_text, ref_id_text, name_text }
end

local M = {}

M.files = Component.new(function(node)
  if not node or not node.children then
    return { tag = "files", children = {} }
  end

  -- Flatten the entire tree structure
  local flattened_entries = flatten_tree(node)

  if #flattened_entries == 0 then
    return { tag = "files", children = {} }
  end

  -- Build first column (main content)
  local main_content_column = {}
  for _, entry in ipairs(flattened_entries) do
    table.insert(main_content_column, create_file_content(entry))
  end

  -- Return single Row with two Columns
  return {
    tag = "files",
    children = {
      Row {
        Column(main_content_column),
      },
    },
  }
end)

M.operations = Component.new(function(operations)
  local children = {}
  for _, operation in ipairs(operations) do
    if operation.type == "create" then
      table.insert(
        children,
        Row {
          Text("CREATE", { highlight = "FylerGreen" }),
          Text " ",
          Text(operation.path, { highlight = "" }),
        }
      )
    elseif operation.type == "delete" then
      table.insert(
        children,
        Row {
          Text("DELETE", { highlight = "FylerRed" }),
          Text " ",
          Text(operation.path, { highlight = "" }),
        }
      )
    elseif operation.type == "move" then
      table.insert(
        children,
        Row {
          Text("MOVE", { highlight = "FylerYellow" }),
          Text " ",
          Text(operation.src, { highlight = "" }),
          Text " ",
          Text(operation.dst, { highlight = "" }),
        }
      )
    elseif operation.type == "copy" then
      table.insert(
        children,
        Row {
          Text("COPY", { highlight = "FylerYellow" }),
          Text " ",
          Text(operation.src, { highlight = "" }),
          Text " ",
          Text(operation.dst, { highlight = "" }),
        }
      )
    else
      error(string.format("Unknown operation type '%s'", operation.type))
    end
  end

  return {
    tag = "operations",
    children = {
      Column(children),
    },
  }
end)

return M
