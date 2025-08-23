local TreeNode = require("fyler.views.explorer.struct")
local Win = require("fyler.lib.win")
local config = require("fyler.config")
local store = require("fyler.views.explorer.store")
local util = require("fyler.lib.util")

local M = {}

local fn = vim.fn

---@class FylerExplorerView
---@field root FylerTreeNode
---@field win FylerWin
local ExplorerView = {}
ExplorerView.__index = ExplorerView

---@param opts { cwd: string, enter: boolean, kind: FylerWinKind|string }
function ExplorerView:open(opts)
  local view_config = config.get_view_config("explorer", opts.kind)
  local mappings = {}

  util.tbl_each(config.get_mappings("explorer"), function(key, action)
    if type(action) == "function" then
      -- if action is a function, wrap it to pass self as the first argument
      mappings[key] = function() action(self) end
      return
    elseif type(action) == "string" then
      local success, native_action = pcall(self._action, self, util.camel_to_snake(string.format("n%s", action)))
      if not success or native_action == nil then
        vim.notify("" .. string.format("Mapping action %s is not available", action), vim.log.levels.WARN)
        return
      end
      mappings[key] = native_action
    end
  end)

  -- stylua: ignore start
  self.win = Win.new {
    autocmds = {
      ["BufReadCmd"]   = self:_action("refreshview"),
      ["BufWriteCmd"]  = self:_action("synchronize"),
      ["CursorMoved"]  = self:_action("constrain_cursor"),
      ["CursorMovedI"] = self:_action("constrain_cursor"),
      ["TextChanged"]  = self:_action("draw_indentscope"),
      ["TextChangedI"] = self:_action("draw_indentscope"),
      ["WinClosed"]    = self:_action("n_close_view"),
    },
    border        = view_config.win.border,
    bottom        = view_config.win.bottom,
    buf_opts      = view_config.win.buf_opts,
    bufname       = string.format("fyler://%s", opts.cwd),
    enter         = opts.enter,
    height        = view_config.win.height,
    kind          = opts.kind,
    left          = view_config.win.left,
    mappings      = mappings,
    name          = "Explorer",
    render        = self:_action("refreshview"),
    right         = view_config.win.right,
    user_autocmds = {
      ["DrawIndentscope"] = self:_action("draw_indentscope"),
      ["RefreshView"]     = self:_action("refreshview"),
      ["Synchronize"]     = self:_action("synchronize"),
    },
    top           = view_config.win.top,
    width         = view_config.win.width,
    win_opts      = view_config.win.win_opts
  }
  -- stylua: ignore end

  self:ch_root(opts.cwd)
  self:ch_kind(opts.kind)
  self.win:show()
end

---@param name string
function ExplorerView:_action(name)
  local action = require("fyler.views.explorer.actions")[name]
  assert(action, string.format("%s action is not available", name))
  return action(self)
end

---@return boolean
function ExplorerView:is_visible() return self.win and self.win:is_visible() end

function ExplorerView:focus()
  if self.win then self.win:focus() end
end

local node_map = {}

---@return string|nil
function ExplorerView:getcwd() return self.root and store.get_entry(self.root.itemid):get_path() end

---@param cwd string
function ExplorerView:ch_root(cwd)
  assert(vim.fn.isdirectory(cwd) == 1, "Path must be a directory")

  if cwd == self:getcwd() then return end

  local new_root = (function()
    if node_map[cwd] then return node_map[cwd] end

    return TreeNode.new(store.set_entry {
      name = fn.fnamemodify(cwd, ":t"),
      path = cwd,
      type = "directory",
    })
  end)()

  self.root = new_root
  self.root.open = true
end

---@param kind FylerWinKind|string
function ExplorerView:ch_kind(kind)
  if self.win then self.win.kind = kind end
end

---@param opts { cwd: string, enter: boolean, kind: FylerWinKind|string }
function M.open(opts)
  M.instance = (function()
    if M.instance then return M.instance end

    return setmetatable({}, ExplorerView)
  end)()

  if M.instance:is_visible() then
    M.instance:focus()
  else
    M.instance:open(opts)
  end
end

return M
