---@module 'fyler.views.file_tree.init'
local IconProvider = require("fyler.lib.ui.icon-provider")
local components = require("fyler.lib.ui.components")

local Line = components.Line
local Word = components.Word
local Mark = components.Mark

local M = {}

---@param tbl FylerTreeViewNode[]
local function get_sorted(tbl)
  table.sort(tbl, function(a, b)
    if a.metadata:is_directory() and not b.metadata:is_directory() then
      return true
    elseif not a.metadata:is_directory() and b.metadata:is_directory() then
      return false
    else
      return a.metadata.name < b.metadata.name
    end
  end)

  return tbl
end

---@param treeNodes FylerTreeViewNode[]
---@return FylerUiLine[]
local function TREE_STRUCTURE(treeNodes, depth)
  local get_icon = IconProvider.get_provider()
  depth = depth or 0

  if not treeNodes then
    return {}
  end

  local lines = {}
  for _, treeNode in ipairs(get_sorted(treeNodes)) do
    local metadata = treeNode.metadata
    local icon = get_icon(metadata)

    table.insert(
      lines,
      Line {
        words = {
          Word(string.rep(" ", depth * 2)),
          Word(icon.text, icon.hl),
          Word(string.format(" %s", metadata.name), metadata.type == "directory" and "FylerBlue" or ""),
          Word(string.format(" /%d", treeNode.node.data)),
        },
        marks = metadata.type == "link" and {
          Mark("--> " .. metadata.links_to.path, "FylerYellow", treeNode.node.data),
        } or {},
      }
    )

    if treeNode.children then
      for _, line in ipairs(TREE_STRUCTURE(treeNode.children, depth + 1)) do
        table.insert(lines, line)
      end
    end
  end

  return lines
end

---@param tbl FylerTreeViewNode
---@return FylerUiLine[]
function M.FileTree(tbl)
  return TREE_STRUCTURE(tbl)
end

return M
