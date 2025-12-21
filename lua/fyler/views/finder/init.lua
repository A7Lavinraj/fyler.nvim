local Files = require "fyler.views.finder.files"
local Path = require "fyler.lib.path"
local Spinner = require "fyler.lib.spinner"
local Win = require "fyler.lib.win"
local async = require "fyler.lib.async"
local config = require "fyler.config"
local fs = require "fyler.lib.fs"
local indent = require "fyler.views.finder.indent"
local input = require "fyler.input"
local parser = require "fyler.views.finder.parser"
local trash = require "fyler.lib.trash"
local ui = require "fyler.views.finder.ui"
local util = require "fyler.lib.util"

---@class Finder
---@field dir string
---@field files Files
local Finder = {}
Finder.__index = Finder

function Finder.new(dir)
  local files = Files.new {
    path = dir,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(dir, ":t"),
  }

  local instance = {
    dir = dir,
    files = files,
  }
  instance.files.finder = instance

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

---@param kind WinKind
---@param bufname string
function Finder:load_with(kind, bufname)
  local rev_maps = config.rev_maps "finder"
  local user_maps = config.user_maps "finder"
  local view = config.view("finder", kind)

  -- stylua: ignore start
  self.win = Win.new {
    autocmds      = {
      ["BufReadCmd"]   = function() self:dispatch_refresh() end,
      ["BufWriteCmd"]  = function() self:synchronize() end,
      ["CursorMoved"]  = function() self:constrain_cursor() end,
      ["CursorMovedI"] = function() self:constrain_cursor() end,
    },
    border        = view.win.border,
    bufname       = bufname,
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
    mappings_opts = view.mappings_opts,
    on_show       = function() indent.enable(self.win) end,
    on_hide       = function() indent.disable() end,
    render        = function()
      self:dispatch_refresh(function()
        local altbufnr = vim.fn.bufnr("#")
        if config.values.views.finder.follow_current_file and altbufnr ~= -1 then
          self:navigate(vim.api.nvim_buf_get_name(altbufnr))
        end
      end)
    end,
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

  return self
end

function Finder:open(kind)
  self:load_with(kind, string.format("fyler://%s", self.dir)).win:show()
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

  self.files:_unregister_watcher(self.files.trie, true)
  self.files = Files.new {
    path = dir,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(dir, ":t"),
  }

  self.dir = dir
  self.files.finder = self

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
---@param on_render function
Finder.dispatch_refresh = util.debounce_wrap(10, function(self, on_render)
  local files_to_table = async.wrap(function(callback)
    self.files:update(nil, function(_, this)
      callback(this:totable())
    end)
  end)

  async.void(function()
    -- Rendering file tree without additional info first
    local files_table = files_to_table()

    -- Have to schedule call due to fast event
    vim.schedule(function()
      self.win.ui:render(ui.files(files_table), function()
        if on_render then
          on_render()
        end

        -- TODO: I don't know why we need to reset syntax on entering fyler buffer with `:e`
        util.set_buf_option(self.win.bufnr, "syntax", "fyler")

        -- Rendering file tree with additional info
        ui.files_with_info(files_table, function(files_with_info_table)
          self.win.ui:render(files_with_info_table)
        end)
      end)
    end)
  end)
end)

function Finder:cursor_node_entry()
  local ref_id = parser.parse_ref_id(vim.api.nvim_get_current_line())
  if ref_id then
    return vim.deepcopy(self.files:node_entry(ref_id))
  end
end

---@param path string
function Finder:navigate(path)
  self.files:focus_path(path, function(_, ref_id)
    if not ref_id then
      return
    end

    self:dispatch_refresh(function()
      if not (self.win:has_valid_winid() and self.win:has_valid_bufnr()) then
        return
      end

      for row, buf_line in ipairs(vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)) do
        if buf_line:find(ref_id) then
          self.win:set_cursor(row, 0)
        end
      end
    end)
  end)
end

local async_wrapped_fs = setmetatable({}, {
  __index = function(_, k)
    return async.wrap(function(...)
      fs[k](...)
    end)
  end,
})

local async_wrapped_trash = setmetatable({}, {
  __index = function(_, k)
    return async.wrap(function(...)
      trash[k](...)
    end)
  end,
})

local function run_mutation(operations)
  local count = 0
  local text = "Mutating (%d/%d)"
  local spinner = Spinner.new(string.format(text, count, #operations))
  local last_focusable_operation = nil
  spinner:start()

  for _, operation in ipairs(operations) do
    if operation.type == "create" then
      async_wrapped_fs.create(operation.path, operation.entry_type == "directory")
    elseif operation.type == "delete" then
      if config.values.views.finder.delete_to_trash then
        async_wrapped_trash.dump(operation.path)
      else
        async_wrapped_fs.delete(operation.path)
      end
    elseif operation.type == "move" then
      async_wrapped_fs.move(operation.src, operation.dst)
    elseif operation.type == "copy" then
      async_wrapped_fs.copy(operation.src, operation.dst)
    end

    if operation.type ~= "delete" then
      last_focusable_operation = operation.path or operation.dst
    end

    count = count + 1
    spinner:set_text(string.format(text, count, #operations))
  end

  spinner:stop()

  return last_focusable_operation
end

---@return boolean
local function can_skip_confirmation(operations)
  local count = { create = 0, delete = 0, move = 0, copy = 0 }
  util.tbl_each(operations, function(o)
    count[o.type] = (count[o.type] or 0) + 1
  end)

  if count.create <= 5 and count.delete == 0 and count.move <= 1 and count.copy <= 1 then
    return true
  end
  return false
end

local get_confirmation = async.wrap(vim.schedule_wrap(function(...)
  input.confirm.open(...)
end))

function Finder:synchronize()
  async.void(function()
    local buf_lines = vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)
    local operations = self.files:diff_with_lines(buf_lines)
    local can_mutate = false
    if vim.tbl_isempty(operations) then
      self:dispatch_refresh()
    elseif config.values.views.finder.confirm_simple and can_skip_confirmation(operations) then
      can_mutate = true
    else
      local cwd = Path.new(self.dir)
      can_mutate = get_confirmation(ui.operations(util.tbl_map(operations, function(operation)
        local _operation = vim.deepcopy(operation)
        if operation.type == "create" or operation.type == "delete" then
          _operation.path = cwd:relative(operation.path)
        else
          _operation.src = cwd:relative(operation.src)
          _operation.dst = cwd:relative(operation.dst)
        end

        return _operation
      end)))
    end

    local last_focusable_operation
    if can_mutate then
      last_focusable_operation = run_mutation(operations)
    end

    if can_mutate then
      self:dispatch_refresh(function()
        if last_focusable_operation then
          self:navigate(last_focusable_operation)
        end
      end)
    end
  end)
end

local M = {
  _current = nil, ---@type Finder|nil
  _instance = {}, ---@type table<string, Finder>
}

---@param dir string|nil
---@param kind WinKind|nil
---@return string, WinKind
local function compute_opts(dir, kind)
  return Path.new(dir or fs.cwd()):normalize(), kind or config.values.views.finder.win.kind
end

function M.open(dir, kind)
  dir, kind = compute_opts(dir, kind)

  local current = M._current
  if not current or not current:same_as(dir, kind) then
    if current then
      current:close()
    end

    current = M._instance[dir] or Finder.new(dir)
    current:open(kind)

    M._instance[dir] = current
    M._current = current
  end
end

function M.close()
  local current = M._current
  if current then
    current:close()
    M._current = nil
  end
end

function M.toggle(dir, kind)
  if M._current then
    M.close()
  else
    M.open(dir, kind)
  end
end

function M.focus()
  local current = M._current
  if current then
    current.win:focus()
  else
    M.open()
  end
end

---@param path string|nil
function M.navigate(path)
  local current = M._current
  if not path or not current or parser.is_protocol_path(path) then
    return
  end

  current:navigate(Path.new(path):normalize())
end

function M.recover()
  local current = M._current
  if not current then
    return
  end

  if current.win:has_valid_winid() and current.win:has_valid_bufnr() and current.win:winbuf() == current.win.bufnr then
    return
  end

  current.win:recover()
  M._current = nil
end

function M.load(url)
  local dir0 = (url:gsub(vim.pesc "fyler://", ""))
  local dir, kind = compute_opts(dir0)

  local current = M._current
  if not current or not current:same_as(dir, kind) then
    if current then
      current:close()
    end

    current = M._instance[dir] or Finder.new(dir)
    current:load_with(kind, url).win:show()

    M._instance[dir] = current
    M._current = current
  end
end

return M
