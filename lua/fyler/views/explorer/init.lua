local TreeNode = require("fyler.views.explorer.struct")
local Win = require("fyler.lib.win")
local config = require("fyler.config")
local store = require("fyler.views.explorer.store")
local util = require("fyler.lib.util")

local M = {}

local api = vim.api
local fn = vim.fn

local instance_map = {}
local current_dir = nil

---@class FylerExplorerView
---@field cwd string
---@field root FylerTreeNode
---@field win FylerWin
local ExplorerView = {}
ExplorerView.__index = ExplorerView

---@param opts { cwd: string, enter: boolean, kind: FylerWinKind|string }
function ExplorerView:open(opts)
  local view_config = config.get_view_config("explorer", opts.kind)
  local mappings = {}
  util.tbl_each(
    config.get_mappings("explorer"),
    function(x, y) mappings[x] = self:_action(util.camel_to_snake(string.format("n%s", y))) end
  )

  FYLER_GLOBAL_STATE.origin_win = api.nvim_get_current_win()
  current_dir = opts.cwd

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
      ["RefreshView"] = self:_action("refreshview"),
      ["Synchronize"] = self:_action("synchronize"),
    },
    top           = view_config.win.top,
    width         = view_config.win.width,
    win_opts      = view_config.win.win_opts
  }
  -- stylua: ignore end

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

---@param cwd string
---@return FylerExplorerView
function M.find_or_create(cwd)
  if instance_map[cwd] then
    current_dir = cwd
    return instance_map[cwd]
  end

  local instance = {
    cwd = cwd,
    root = TreeNode.new(store.set_entry {
      name = fn.fnamemodify(cwd, ":t"),
      path = cwd,
      type = "directory",
    }),
  }

  instance.root:toggle()
  instance_map[cwd] = setmetatable(instance, ExplorerView)

  return instance
end

---@param cwd string
---@return FylerExplorerView
function M.get_instance(cwd)
  if current_dir == cwd then return instance_map[current_dir] end

  local current_instance = M.get_current_instance()
  if current_instance then current_instance.win:hide() end

  current_dir = cwd
  instance_map[current_dir] = M.find_or_create(current_dir)

  return instance_map[current_dir]
end

---@return FylerExplorerView|nil
function M.get_current_instance()
  if not current_dir then return nil end

  return instance_map[current_dir]
end

---@param opts { cwd: string, enter: boolean, kind: FylerWinKind|string }
function M.open(opts)
  local instance = M.get_instance(opts.cwd)
  if instance:is_visible() then
    instance:focus()
  else
    instance:open(opts)
  end
end

return M
