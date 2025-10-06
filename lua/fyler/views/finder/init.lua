local Files = require "fyler.views.finder.files.init"
local Path = require "fyler.lib.path"
local Win = require "fyler.lib.win"
local a = require "fyler.lib.async"
local config = require "fyler.config"
local fs = require "fyler.lib.fs"
local input = require "fyler.input"
local parser = require "fyler.views.finder.parser"
local ui = require "fyler.views.finder.ui"
local util = require "fyler.lib.util"

---@class Finder
---@field dir string
---@field files Files
---@field config table
local Finder = {}
Finder.__index = Finder

function Finder.new(dir, config)
  local files = Files.new({
    path = dir,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(dir, ":t"),
  }):update()

  local instance = {
    dir = dir,
    files = files,
    config = config,
  }

  setmetatable(instance, Finder)

  return instance
end

---@param name string
function Finder:_action(name)
  local action = require("fyler.views.finder.actions")[name]
  assert(action, string.format("action %s is not available", name))

  return action(self)
end

---@param user_mappings table<string, function>
---@return table<string, function>
function Finder:_action_mod(user_mappings)
  local actions = {}
  for keys, fn in pairs(user_mappings) do
    actions[keys] = function()
      fn(self)
    end
  end

  return actions
end

---@param dir string
---@param kind WinKind
---@return boolean
function Finder:same_as(dir, kind)
  return self.dir == dir and self.win.kind == kind
end

function Finder:open(kind)
  local rev_maps = self.config.rev_maps "finder"
  local user_maps = self.config.user_maps "finder"
  local view = self.config.view("finder", kind)

  -- stylua: ignore start
  self.win = Win.new {
    autocmds      = {
      ["BufReadCmd"]   = function() self:dispatch_refresh() end,
      ["BufWriteCmd"]  = function() self:synchronize() end,
      ["CursorMoved"]  = function() self:constrain_cursor() end,
      ["CursorMovedI"] = function() self:constrain_cursor() end,
    },
    border        = view.win.border,
    bufname       = string.format("fyler://%s", self.dir),
    bottom        = view.win.bottom,
    buf_opts      = view.win.buf_opts,
    enter         = true,
    footer        = view.win.footer,
    footer_pos    = view.win.footer_pos,
    height        = view.win.height,
    kind          = kind,
    left          = view.win.left,
    mappings      = {
      [rev_maps["CloseView"]]    = self:_action "n_close",
      [rev_maps["CollapseAll"]]  = self:_action "n_collapse_all",
      [rev_maps["CollapseNode"]] = self:_action "n_collapse_node",
      [rev_maps["GotoCwd"]]      = self:_action "n_goto_cwd",
      [rev_maps["GotoNode"]]     = self:_action "n_goto_node",
      [rev_maps["GotoParent"]]   = self:_action "n_goto_parent",
      [rev_maps["Select"]]       = self:_action "n_select",
      [rev_maps["SelectSplit"]]  = self:_action "n_select_split",
      [rev_maps["SelectTab"]]    = self:_action "n_select_tab",
      [rev_maps["SelectVSplit"]] = self:_action "n_select_v_split",
    },
    render        = function() self:dispatch_refresh() end,
    right         = view.win.right,
    title         = string.format(" %s ", self.dir),
    title_pos     = view.win.title_pos,
    top           = view.win.top,
    user_autocmds = {
      ["DispatchRefresh"] = function() self:dispatch_refresh() end,
    },
    user_mappings = self:_action_mod(user_maps),
    width         = view.win.width,
    win_opts      = view.win.win_opts,
  }
  -- stylua: ignore end

  self.win:show()
end

function Finder:close()
  if self.win then
    self.win:hide()
  end
end

function Finder:exec_action(name, ...)
  local action = require("fyler.views.finder.actions")[name]
  assert(action, string.format("action %s is not available", name))
  action(self)(...)
end

---@param dir string
function Finder:chdir(dir)
  assert(dir, "cannot change directory with empty path")

  self.files = Files.new({
    path = dir,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(dir, ":t"),
  }):update()

  if self.win then
    self.win:update_title(string.format(" %s ", dir))
  end
end

function Finder:constrain_cursor()
  local cur = vim.api.nvim_get_current_line()
  local ref_id = parser.parse_ref_id(cur)
  if not ref_id then
    return
  end

  local _, ub = string.find(cur, ref_id)
  if not self.win:has_valid_winid() then
    return
  end

  local row, col = self.win:get_cursor()
  if not (row and col) then
    return
  end

  if col <= ub then
    self.win:set_cursor(row, ub + 1)
  end
end

---@param self Finder
---@param callback function
Finder.dispatch_refresh = a.void_wrap(function(self, callback)
  self.win.ui:render(ui.files(self.files:update():totable()), callback)
end)

function Finder:cursor_node_entry()
  local ref_id = parser.parse_ref_id(vim.api.nvim_get_current_line())
  if ref_id then
    return vim.deepcopy(self.files:node_entry(ref_id))
  end
end

---@param path string
function Finder:track_buffer(path)
  if parser.is_protocol_path(path) then
    if not util.is_valid_bufnr(self.win.old_bufnr) then
      return
    end

    path = vim.fn.bufname(self.win.old_bufnr)
    if parser.is_protocol_path(path) then
      return
    end
  end

  local ref_id = self.files:focus_path(path)
  if not ref_id then
    return
  end

  self:dispatch_refresh(function()
    if not (self.win:has_valid_winid() and self.win:has_valid_bufnr()) then
      return
    end

    if not parser.is_protocol_path(vim.api.nvim_buf_get_name(0)) then
      self.win.old_bufnr = vim.api.nvim_get_current_buf()
      self.win.old_winid = vim.api.nvim_get_current_win()
    end

    for row, buf_line in ipairs(vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)) do
      if buf_line:find(ref_id) then
        self.win:set_cursor(row, 0)
      end
    end
  end)
end

local function run_mutation(operations)
  for _, operation in ipairs(operations) do
    if operation.type == "create" then
      fs.create(operation.path, operation.entry_type == "directory")
    elseif operation.type == "delete" then
      fs.delete(operation.path)
    elseif operation.type == "move" then
      fs.move(operation.src, operation.dst)
    elseif operation.type == "copy" then
      fs.copy(operation.src, operation.dst)
    end
  end
end

Finder.synchronize = a.void_wrap(function(self)
  local buf_lines = vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)
  local operations = self.files:diff_with_lines(buf_lines)

  local can_mutate
  if self.config.values.confirm_simple then
    can_mutate = true
  else
    can_mutate = input.confirm.open_async(ui.operations(operations))
  end

  if can_mutate then
    run_mutation(operations)

    self:dispatch_refresh()
  end
end)

local M = {
  _current = nil, ---@type Finder|nil
  _instance = {}, ---@type table<string, Finder>
}

---@param dir string|nil
---@param kind WinKind|nil
---@param config table
---@return string, WinKind
local function compute_opts(dir, kind, config)
  return dir or fs.cwd(), kind or config.values.views.finder.win.kind
end

---@param dir string|nil
---@param kind WinKind|nil
function M.open(dir, kind)
  dir, kind = compute_opts(dir, kind, config)

  if not M._current then
    M._current = M._instance[dir] or Finder.new(dir, config)
    M._current:open(kind)
  else
    if not M._current:same_as(dir, kind) then
      M._current:close()
      M._current = M._instance[dir] or Finder.new(dir, config)
      M._current:open(kind)
    end
  end
end

function M.close()
  if M._current then
    M._current:close()
    M._current = nil
  end
end

function M.toggle(dir, kind)
  dir, kind = compute_opts(dir, kind, config)

  if M._current then
    M.close()
  else
    M.open(dir, kind)
  end
end

---@param name string|nil
function M.track_buffer(name)
  local current = M._current
  if not current then
    return
  end

  if not name or parser.is_protocol_path(name) then
    name = vim.api.nvim_buf_get_name(current.win.old_bufnr)
  end

  current:track_buffer(Path.new(name):abspath())
end

---@return boolean
function M.is_valid()
  local current = M._current
  return not current
    or not current.win:has_valid_winid()
    or not current.win:has_valid_bufnr()
    or current.win:winbuf() == current.win.bufnr
end

function M.recover()
  if M.is_valid() then
    return
  end

  M._current.win:recover()
  M._current = nil
end

return M
