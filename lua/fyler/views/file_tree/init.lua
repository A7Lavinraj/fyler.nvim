local TreeNode = require("fyler.views.file_tree.struct")
local Win = require("fyler.lib.win")
local config = require("fyler.config")
local fs = require("fyler.lib.fs")
local regex = require("fyler.views.file_tree.regex")
local store = require("fyler.views.file_tree.store")
local ui = require("fyler.views.file_tree.ui")

local fn = vim.fn
local api = vim.api

---@class FylerTreeView
---@field cwd       string
---@field win       FylerWin
---@field tree_node FylerTreeNode
local FileTreeView = {}
FileTreeView.__index = FileTreeView

---@class FylerTreeViewOpenOpts
---@field cwd           string
---@field focused_path? string
---@field kind?         FylerWinKind

---@param opts FylerTreeViewOpenOpts
function FileTreeView.new(opts)
  local tree_node = TreeNode(store.set {
    name = fn.fnamemodify(opts.cwd, ":t"),
    type = "directory",
    path = opts.cwd,
  })

  tree_node:toggle()

  local instance = {
    cwd = opts.cwd,
    kind = opts.kind,
    tree_node = tree_node,
  }

  setmetatable(instance, FileTreeView)

  return instance
end

---@param opts FylerTreeViewOpenOpts
function FileTreeView:open(opts)
  local mappings = config.get_reverse_mappings("file_tree")

  self:update_tree()

  local rel = vim.fs.relpath(opts.cwd, opts.focused_path or "")
  local parts = {}
  if rel then
    parts = vim.split(rel, "/")
  end

  local focused_node = self.tree_node
  for _, part in pairs(parts) do
    local child = vim.iter(focused_node.children):find(function(child)
      return store.get(child.data).name == part
    end)
    if not child then
      break
    end
    child.open = true
    child:update()
    focused_node = child
  end

  self.win = Win {
    enter = true,
    name = "file_tree",
    bufname = string.format("fyler://%s", self.cwd),
    kind = opts.kind,
    bufopts = {
      syntax = "fyler",
      filetype = "fyler",
      buftype = "acwrite",
    },
    winopts = {
      wrap = false,
      number = true,
      relativenumber = true,
      conceallevel = 3,
      concealcursor = "nvic",
      cursorline = true,
    },
    -- stylua: ignore start
    mappings = {
      n = {
        [mappings["Select"]]          = self:_action("n_select"),
        [mappings["SelectRecursive"]] = self:_action("n_select_recursive"),
        [mappings["CloseView"]]       = self:_action("n_close_view"),
      },
    },
    autocmds = {
      ["WinClosed"]   = self:_action("n_close_view"),
      ["BufReadCmd"]  = self:_action("n_refreshview"),
      ["BufWriteCmd"] = self:_action("n_synchronize"),
      ["CursorMoved"] = self:_action("constrain_cursor"),
      ["CursorMovedI"] = self:_action("constrain_cursor"),
    },
    user_autocmds = {
      ["RefreshView"] = self:_action("n_refreshview"),
      ["Synchronize"] = self:_action("n_synchronize"),
    },
    -- stylua: ignore end
    render = function()
      return ui.FileTree(self:tree_table_from_node().children)
    end,
    on_open = function()
      vim.fn.search(string.format("/%s$", focused_node.data), "w")
      vim.cmd(":normal _")
    end,
  }

  require("fyler.cache").set_entry("recent_win", api.nvim_get_current_win())

  self.win:show()
end

function FileTreeView:close()
  self.win:hide()
end

---@param name string
function FileTreeView:_action(name)
  local action = require("fyler.views.file_tree.actions")[name]

  assert(action, string.format("%s action is not available", name))

  return action(self)
end

---@return FylerTreeView
function FileTreeView:update_tree()
  self.tree_node:update()
  return self
end

---@alias FylerTreeViewNode { node: FylerTreeNode, metadata: FileMetadata, children: FylerTreeViewNode[] }
---@return FylerTreeViewNode
function FileTreeView:tree_table_from_node()
  ---@param tree_node FylerTreeNode
  ---@return FylerTreeViewNode
  local function get_tbl(tree_node)
    return {
      node = tree_node,
      metadata = store.get(tree_node.data),
      children = tree_node.open and vim.iter(tree_node.children):map(get_tbl):totable() or {},
    }
  end

  return get_tbl(self.tree_node)
end

---@return table
function FileTreeView:tree_table_from_buffer()
  if not self.win:has_valid_bufnr() then
    return {}
  end

  local buf_lines = vim
    .iter(api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false))
    :filter(function(buf_line)
      return buf_line ~= ""
    end)
    :totable()

  if #buf_lines == 0 then
    return {}
  end

  local root = vim.tbl_deep_extend("force", store.get(self.tree_node.data), {
    key = self.tree_node.data,
    children = {},
  })

  local stack = {
    { node = root, indent = -1 },
  }

  for _, buf_line in ipairs(buf_lines) do
    local key = regex.getkey(buf_line)
    local name = regex.getname(buf_line)
    local indent = regex.getindent(buf_line)
    local metadata = key and store.get(key)

    while #stack > 1 and #stack[#stack].indent >= #indent do
      table.remove(stack)
    end

    local parent = stack[#stack].node
    local path = fs.joinpath(parent.path, name)
    local new_node = { key = key, name = name, type = (metadata or {}).type or "", path = path }

    table.insert(parent.children, new_node)

    if metadata and metadata:is_directory() then
      new_node.children = {}
      table.insert(stack, { node = new_node, indent = indent })
    end
  end

  return root
end

---@return table
function FileTreeView:get_diff()
  local recent_tree_hash = {}

  local function save_hash(root)
    recent_tree_hash[root.node.data] = root.metadata.path

    for _, child in ipairs(root.children or {}) do
      save_hash(child)
    end
  end

  save_hash(self:tree_table_from_node())

  local ops_tbl = {
    create = {},
    delete = {},
    move = {},
  }

  local function calculate_ops(root)
    if not root.key then
      table.insert(ops_tbl.create, root.path)
    else
      if recent_tree_hash[root.key] ~= root.path then
        table.insert(ops_tbl.move, { from = recent_tree_hash[root.key], to = root.path })
      end

      recent_tree_hash[root.key] = nil
    end

    for _, child in ipairs(root.children or {}) do
      calculate_ops(child)
    end
  end

  calculate_ops(self:tree_table_from_buffer())

  for _, v in pairs(recent_tree_hash) do
    if v then
      table.insert(ops_tbl.delete, v)
    end
  end

  return ops_tbl
end

function FileTreeView:refresh()
  self.win.ui:render(ui.FileTree(self:update_tree():tree_table_from_node().children))
  vim.bo[self.win.bufnr].syntax = "fyler"
  vim.bo[self.win.bufnr].filetype = "fyler"
end

local M = {
  instance = {},
}

---@param opts { cwd?: string, kind?: FylerWinKind, focused_path?: string }
function M.open(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or fs.getcwd()
  opts.focused_path = opts.focused_path or api.nvim_buf_get_name(0)
  opts.kind = opts.kind or config.get_view("file_tree").kind

  if M.instance.close then
    M.instance:close()
  end

  if M.instance.cwd ~= opts.cwd then
    M.instance = FileTreeView.new {
      cwd = opts.cwd,
      kind = opts.kind,
    }
  end

  M.instance:open(opts)
end

return M
