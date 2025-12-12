local Ui = require "fyler.lib.ui"
local config = require "fyler.config"
local git = require "fyler.lib.git"
local util = require "fyler.lib.util"

local Component = Ui.Component
local Text = Ui.Text
local Row = Ui.Row
local Column = Ui.Column

local function is_directory(node)
  return node.type == "directory"
end

local function sort_nodes(nodes)
  table.sort(nodes, function(x, y)
    local x_is_dir = is_directory(x)
    local y_is_dir = is_directory(y)
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
  local icon, hl = config.icon_provider(item.type, item.path)
  if not icon or icon == "" then
    return
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

local M = {}

M.files = Component.new_async(function(node, onchunk)
  if not node or not node.children then
    return onchunk { tag = "files", children = {} }
  end

  local flattened_entries = flatten_tree(node)

  if #flattened_entries == 0 then
    return onchunk { tag = "files", children = {} }
  end

  local files_column = {}
  for _, e in ipairs(flattened_entries) do
    local item, depth = e.item, e.depth
    local icon, hl = icon_and_hl(item)

    local icon_highlight = (item.type == "directory") and "FylerFSDirectoryIcon" or hl
    local name_highlight = (item.type == "directory") and "FylerFSDirectoryName" or nil

    icon = icon and (icon .. " ") or ""

    local indentation_text = Text(string.rep(" ", 2 * depth))
    local icon_text = Text(icon, { highlight = icon_highlight })
    local ref_id_text = item.ref_id and Text(string.format("/%05d ", item.ref_id)) or Text ""
    local name_text = Text(item.name, { highlight = name_highlight })

    table.insert(files_column, Row { indentation_text, icon_text, ref_id_text, name_text })
  end

  onchunk { tag = "files", children = { Row { Column(files_column) } } }

  if config.values.views.finder.git_status.enabled then
    git.map_entries_async(
      node.path,
      util.tbl_map(flattened_entries, function(e)
        return e.item.path
      end),
      function(git_entries)
        local git_highlights = {}
        local gitst_column = {}
        for i, e in ipairs(git_entries) do
          table.insert(gitst_column, Text(nil, { virt_text = { e } }))
          git_highlights[i] = e[2]
        end

        for i, e in ipairs(flattened_entries) do
          local item = e.item
          local git_hl = git_highlights[i]
          local name_highlight = git_hl or ((item.type == "directory") and "FylerFSDirectoryName" or nil)
          local row = files_column[i]
          if row and row.children and row.children[4] then
            row.children[4].option = row.children[4].option or {}
            row.children[4].option.highlight = name_highlight
          end
        end

        onchunk({ tag = "files", children = { Row { Column(files_column), Column(gitst_column) } } }, true)
      end
    )
  end
end)

M.operations = Component.new(function(operations)
  local types = {}
  local details = {}
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
      table.insert(
        details,
        Row {
          Text(operation.src),
          Text " > ",
          Text(operation.dst),
        }
      )
    elseif operation.type == "copy" then
      table.insert(types, Text("COPY", { highlight = "FylerBlue" }))
      table.insert(
        details,
        Row {
          Text(operation.src),
          Text " > ",
          Text(operation.dst),
        }
      )
    else
      error(string.format("Unknown operation type '%s'", operation.type))
    end
  end

  return {
    tag = "operations",
    children = {
      Row {
        Column(types),
        Text " ",
        Column(details),
      },
    },
  }
end)

return M
