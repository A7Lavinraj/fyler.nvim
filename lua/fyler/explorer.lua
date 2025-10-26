local Tree = require "fyler.explorer.file_tree"
local Win = require "fyler.lib.win"
local a = require "fyler.lib.async"
local e_util = require "fyler.explorer.util"
local fs = require "fyler.lib.fs"
local ui = require "fyler.explorer.ui"
local util = require "fyler.lib.util"
local api = vim.api
local fn = vim.fn

---@class Explorer
---@field dir string
---@field win Win
---@field file_tree FileTree
---@field config table
local M = {}
M.__index = M

---@type table<string, Explorer>
local instances = {}
---@type string|nil
local recentdir

---@param dir string
---@param instance Explorer
function M.register(dir, instance)
  assert(dir, "cannot register without directory")

  instances[dir] = instance
end

---@param dir string|nil
---@return Explorer|nil
function M.instance(dir)
  return instances[dir]
end

---@return Explorer|nil
function M.current()
  return M.instance(recentdir)
end

---@param dir string
---@param config table
---@return Explorer
function M.new(dir, config)
  local instance = {
    dir = dir,
    config = config,
  }

  setmetatable(instance, M)
  M.register(dir, instance)

  return instance
end

---@return string|nil
function M:getcwd()
  if self.file_tree then
    return self.file_tree:node_entry(self.file_tree.tree.root.value).path
  else
    return nil
  end
end

---@param dir string
function M:chdir(dir)
  assert(dir, "cannot change directory with empty path")

  self.file_tree = Tree.new(fn.fnamemodify(dir, ":t"), true, dir, "directory")
  self.file_tree:update()

  if self.win then
    self.win:update_title(string.format(" %s ", dir))
  end
end

---@return boolean
function M:is_visible()
  return self.win and self.win:is_visible()
end

---@param dir string
---@param kind WinKind
function M:eq_with(dir, kind)
  return self.dir == dir and self.win.kind == kind
end

function M:focus()
  if self.win then
    self.win:focus()
  end
end

---@param dir string
---@param kind WinKind
function M:open(dir, kind)
  local reversed_maps = self.config.get_reversed_maps()

  if self:getcwd() == dir then
    if self:is_visible() then
      self:focus()
      return
    end
  else
    self:chdir(dir)
  end

  local win = self.config.build_win(kind)
  recentdir = dir

  -- stylua: ignore start
  self.win = Win.new {
    autocmds      = {
      ["BufReadCmd"]   = function() self:dispatch_refresh() end,
      ["BufWriteCmd"]  = function() self:synchronize() end,
      ["CursorMoved"]  = function() self:constrain_cursor() self:draw_indentscope() end,
      ["CursorMovedI"] = function() self:constrain_cursor() self:draw_indentscope() end,
      ["TextChanged"]  = function() self:draw_indentscope() end,
      ["TextChangedI"] = function() self:draw_indentscope() end,
      ["WinClosed"]    = function() self:close() end,
    },
    border        = win.border,
    bufname       = string.format("fyler://%s", dir),
    bottom        = win.bottom,
    buf_opts      = win.buf_opts,
    enter         = true,
    footer        = win.footer,
    footer_pos    = win.footer,
    height        = win.height,
    kind          = kind,
    left          = win.left,
    mappings      = {
      [reversed_maps["CloseView"]]    = self:_action "n_close",
      [reversed_maps["CollapseAll"]]  = self:_action "n_collapse_all",
      [reversed_maps["CollapseNode"]] = self:_action "n_collapse_node",
      [reversed_maps["GotoCwd"]]      = self:_action "n_goto_cwd",
      [reversed_maps["GotoNode"]]     = self:_action "n_goto_node",
      [reversed_maps["GotoParent"]]   = self:_action "n_goto_parent",
      [reversed_maps["Select"]]       = self:_action "n_select",
      [reversed_maps["SelectSplit"]]  = self:_action "n_select_split",
      [reversed_maps["SelectTab"]]    = self:_action "n_select_tab",
      [reversed_maps["SelectVSplit"]] = self:_action "n_select_v_split",
    },
    render        = function() self:dispatch_refresh() end,
    right         = win.right,
    title         = string.format(" %s ", dir),
    title_pos     = win.title,
    top           = win.top,
    user_autocmds = {
      ["DispatchRefresh"] = function() self:dispatch_refresh() end,
      ["DrawIndentscope"] = function() self:draw_indentscope() end,
    },
    user_mappings = self:_action_mod(self.config.get_user_mappings()),
    width         = win.width,
    win_opts      = win.win_opts,
  }
  -- stylua: ignore end

  self.win:show()
end

---@param name string
function M:_action(name)
  local action = require("fyler.explorer.actions")[name]
  assert(action, string.format("action %s is not available", name))

  return action(self)
end

---@param user_mappings table<string, function>
---@return table<string, function>
function M:_action_mod(user_mappings)
  local actions = {}
  for keys, fn in pairs(user_mappings) do
    actions[keys] = function()
      fn(self)
    end
  end

  return actions
end

function M:close()
  if self.win then
    self.win:hide()
  end
end

---@return Entry|nil
function M:cursor_node_entry()
  local ref_id = e_util.parse_ref_id(api.nvim_get_current_line())
  if ref_id then
    return self.file_tree:node_entry(ref_id)
  end
end

function M:constrain_cursor()
  local cur = api.nvim_get_current_line()
  local ref_id = e_util.parse_ref_id(cur)
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

---@param name string
function M:track_buffer(name)
  if not name then
    return
  end

  if e_util.is_protocol_path(name) then
    if not util.is_valid_bufnr(self.win.old_bufnr) then
      return
    end

    name = fn.bufname(self.win.old_bufnr)
    if e_util.is_protocol_path(name) then
      return
    end
  end

  name = fs.abspath(name)
  if not fs.exists(name) then
    return
  end

  local current_dir = self:getcwd()
  if not current_dir then
    return
  end

  local ref_id = self.file_tree:focus_path(name)
  if not ref_id then
    return
  end

  self:dispatch_refresh(function()
    if not (self.win:has_valid_winid() and self.win:has_valid_bufnr()) then
      return
    end

    if not e_util.is_protocol_path(api.nvim_buf_get_name(0)) then
      self.win.old_bufnr = api.nvim_get_current_buf()
      self.win.old_winid = api.nvim_get_current_win()
    end

    for row, buf_line in ipairs(api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)) do
      if buf_line:find(ref_id) then
        self.win:set_cursor(row, 0)
      end
    end
  end)
end

---@param self Explorer
---@param callback function
M.dispatch_refresh = a.void_wrap(function(self, callback)
  self.win.ui:render(ui(self.file_tree:update():totable()), callback)
end)

local extmark_namespace = api.nvim_create_namespace "Fyler-indent-scope"
local function process_line(self, ln)
  if not self.win:has_valid_bufnr() then
    return
  end

  local cur_line = util.unpack(api.nvim_buf_get_lines(self.win.bufnr, ln - 1, ln, false))
  local cur_indent = e_util.parse_indent_level(cur_line)
  if cur_indent == 0 then
    return
  end

  local scrolled_cols = vim.fn.winsaveview().leftcol
  local indent_depth = math.floor(cur_indent * 0.5) - scrolled_cols
  for i = 1, indent_depth do
    api.nvim_buf_set_extmark(self.win.bufnr, extmark_namespace, ln - 1, 0, {
      hl_mode = "combine",
      virt_text = {
        {
          self.config.values.indentscope.marker,
          self.config.values.indentscope.group,
        },
      },
      virt_text_pos = "overlay",
      virt_text_win_col = (i - 1) * 2,
    })
  end
end

function M:draw_indentscope()
  if not self.win:has_valid_bufnr() then
    return
  end
  if not self.config.values.indentscope.enabled then
    return
  end

  api.nvim_buf_clear_namespace(self.win.bufnr, extmark_namespace, 0, -1)
  for i = 1, api.nvim_buf_line_count(self.win.bufnr) do
    process_line(self, i)
  end
end

local function parent(path)
  return vim.fn.fnamemodify(path, ":h")
end

local function isdir(path)
  return vim.fn.isdirectory(path) == 1
end

local function sort_by_depth(paths, reverse)
  table.sort(paths, function(a, b)
    local depth_a = select(2, string.gsub(a, "/", ""))
    local depth_b = select(2, string.gsub(b, "/", ""))
    if reverse then
      return depth_a > depth_b
    else
      return depth_a < depth_b
    end
  end)
  return paths
end

local function get_ordered_operations(changes)
  local operations = {}
  local deleted_paths = {}

  for _, change in ipairs(changes.delete) do
    deleted_paths[change] = true
  end

  for _, change in ipairs(changes.move) do
    deleted_paths[change.src] = true
  end

  local files_to_delete = {}
  for _, change in ipairs(changes.delete) do
    if not isdir(change) then
      table.insert(files_to_delete, change)
    end
  end
  sort_by_depth(files_to_delete, true)

  for _, change in ipairs(files_to_delete) do
    table.insert(operations, { type = "delete", path = change })
  end

  local dirs_to_create = {}
  local processed_dirs = {}

  local all_destinations = {}

  for _, change in ipairs(changes.create) do
    if isdir(change) then
      table.insert(all_destinations, change)
    else
      table.insert(all_destinations, parent(change))
    end
  end

  for _, change in ipairs(changes.move) do
    table.insert(all_destinations, parent(change.dst))
  end

  for _, change in ipairs(changes.copy) do
    table.insert(all_destinations, parent(change.dst))
  end

  for _, dest in ipairs(all_destinations) do
    local current = dest

    while
      current
      and current ~= "."
      and current ~= "/"
      and not current:find "^[A-Za-z]:/$"
      and not processed_dirs[current]
    do
      if not vim.fn.isdirectory(current) == 1 and not deleted_paths[current] then
        table.insert(dirs_to_create, current)
        processed_dirs[current] = true
      end

      current = parent(current)
    end
  end

  sort_by_depth(dirs_to_create, false)

  for _, dir in ipairs(dirs_to_create) do
    table.insert(operations, { type = "create", path = dir })
  end

  for _, change in ipairs(changes.create) do
    if not processed_dirs[change] then
      table.insert(operations, { type = "create", path = change })
    end
  end

  for _, change in ipairs(changes.move) do
    table.insert(operations, { type = "move", src = change.src, dst = change.dst })
  end

  for _, change in ipairs(changes.copy) do
    table.insert(operations, { type = "copy", src = change.src, dst = change.dst })
  end

  local dirs_to_delete = {}
  for _, change in ipairs(changes.delete) do
    if isdir(change) then
      table.insert(dirs_to_delete, change)
    end
  end
  sort_by_depth(dirs_to_delete, true)

  for _, change in ipairs(dirs_to_delete) do
    table.insert(operations, { type = "delete", path = change })
  end

  return operations
end

---@param self Explorer
---@param tbl table
---@return table
local function get_tbl(self, tbl)
  local lines = {}
  if not self then
    return lines
  end

  local ordered_operations = get_ordered_operations(tbl)

  local grouped_ops = {}
  local seen_types = {}

  for _, op in ipairs(ordered_operations) do
    if not grouped_ops[op.type] then
      grouped_ops[op.type] = {}
      table.insert(seen_types, op.type)
    end
    table.insert(grouped_ops[op.type], op)
  end

  for _, op_type in ipairs(seen_types) do
    local ops = grouped_ops[op_type]

    if op_type == "delete" then
      table.insert(lines, { { str = "DELETE", hlg = "FylerRed" } })
      for _, op in ipairs(ops) do
        table.insert(lines, { { str = fs.relpath(self:getcwd(), op.path) } })
      end
      table.insert(lines, { { str = "" } })
    elseif op_type == "create" then
      table.insert(lines, { { str = "CREATE", hlg = "FylerGreen" } })
      for _, op in ipairs(ops) do
        table.insert(lines, { { str = fs.relpath(self:getcwd(), op.path) } })
      end
      table.insert(lines, { { str = "" } })
    elseif op_type == "move" then
      table.insert(lines, { { str = "MOVE", hlg = "FylerYellow" } })
      for _, op in ipairs(ops) do
        table.insert(lines, {
          { str = fs.relpath(self:getcwd(), op.src) },
          { str = " > " },
          { str = fs.relpath(self:getcwd(), op.dst) },
        })
      end
      table.insert(lines, { { str = "" } })
    elseif op_type == "copy" then
      table.insert(lines, { { str = "COPY", hlg = "FylerYellow" } })
      for _, op in ipairs(ops) do
        table.insert(lines, {
          { str = fs.relpath(self:getcwd(), op.src) },
          { str = " > " },
          { str = fs.relpath(self:getcwd(), op.dst) },
        })
      end
      table.insert(lines, { { str = "" } })
    end
  end

  return lines
end

---@param changes table
---@return boolean
local function can_bypass(changes)
  if #changes.copy > 1 then
    return false
  end
  if #changes.move > 1 then
    return false
  end
  if #changes.create > 5 then
    return false
  end
  if not vim.tbl_isempty(changes.delete) then
    return false
  end
  return true
end

local function run_mutation(changes)
  local ordered_operations = get_ordered_operations(changes)

  for _, op in ipairs(ordered_operations) do
    if op.type == "copy" then
      fs.copy(op.src, op.dst)
    elseif op.type == "move" then
      fs.move(op.src, op.dst)
    elseif op.type == "create" then
      fs.create(op.path)
    elseif op.type == "delete" then
      fs.delete(op.path)
    end
  end
end

local function has_changes(changes)
  return #changes.create + #changes.delete + #changes.move + #changes.copy > 0
end

M.synchronize = a.void_wrap(function(self)
  local popups = require "fyler.popups"

  local buf_lines = api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)
  local changes = self.file_tree:diff_with_lines(buf_lines)

  local can_mutate
  if not has_changes(changes) or self.config.values.confirm_simple and can_bypass(changes) then
    can_mutate = true
  else
    can_mutate = popups.permission.create(get_tbl(self, changes))
  end

  if can_mutate then
    run_mutation(changes)

    self:dispatch_refresh()
  end
end)

return M
