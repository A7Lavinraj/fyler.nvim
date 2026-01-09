local Path = require "fyler.lib.path"
local async = require "fyler.lib.async"
local config = require "fyler.config"
local helper = require "fyler.views.finder.helper"
local util = require "fyler.lib.util"

local M = {}

---@class Finder
---@field uri string
---@field files Files
---@field watcher Watcher
local Finder = {}
Finder.__index = Finder

function Finder.new(uri)
  return setmetatable({ uri = uri }, Finder)
end

---@param name string
function Finder:action(name)
  local action = require("fyler.views.finder.actions")[name]
  return assert(action, string.format("action %s is not available", name))(self)
end

---@param user_mappings table<string, function>
---@return table<string, function>
function Finder:action_wrap(user_mappings)
  local actions = {}
  for keys, fn in pairs(user_mappings) do
    actions[keys] = function()
      fn(self)
    end
  end
  return actions
end

---@param name string
---@param ... any
function Finder:action_call(name, ...)
  self:action(name)(...)
end

---@deprecated
function Finder:exec_action(...)
  vim.notify "'exec_action' is deprecated use 'call_action'"
  self:action_call(...)
end

---@param kind WinKind|nil
function Finder:isopen(kind)
  return self.win
    and (kind and (self.win.kind == kind) or true)
    and self.win:has_valid_winid()
    and self.win:has_valid_bufnr()
end

---@param kind WinKind
function Finder:open(kind)
  local indent = require "fyler.views.finder.indent"

  local rev_maps = config.rev_maps "finder"
  local usr_maps = config.usr_maps "finder"
  local view_cfg = config.view_cfg("finder", kind)

  -- stylua: ignore start
  self.win = require("fyler.lib.win").new {
    autocmds      = {
      ["BufReadCmd"] = function() self:dispatch_refresh() end,
      ["BufWriteCmd"] = function() self:dispatch_mutation() end,
      [{"CursorMoved","CursorMovedI"}] = function() self:clamp_cursor() end,
    },
    border        = view_cfg.win.border,
    bufname       = self.uri,
    bottom        = view_cfg.win.bottom,
    buf_opts      = view_cfg.win.buf_opts,
    enter         = true,
    footer        = view_cfg.win.footer,
    footer_pos    = view_cfg.win.footer_pos,
    height        = view_cfg.win.height,
    kind          = kind,
    left          = view_cfg.win.left,
    mappings      = {
      [rev_maps["CloseView"]]    = self:action "n_close",
      [rev_maps["CollapseAll"]]  = self:action "n_collapse_all",
      [rev_maps["CollapseNode"]] = self:action "n_collapse_node",
      [rev_maps["GotoCwd"]]      = self:action "n_goto_cwd",
      [rev_maps["GotoNode"]]     = self:action "n_goto_node",
      [rev_maps["GotoParent"]]   = self:action "n_goto_parent",
      [rev_maps["Select"]]       = self:action "n_select",
      [rev_maps["SelectSplit"]]  = self:action "n_select_split",
      [rev_maps["SelectTab"]]    = self:action "n_select_tab",
      [rev_maps["SelectVSplit"]] = self:action "n_select_v_split",
    },
    mappings_opts = view_cfg.mappings_opts,
    on_show       = function()
      self.watcher:enable()
      indent.attach(self.win)
    end,
    on_hide       = function()
      self.watcher:disable()
      indent.detach(self.win)
    end,
    render        = function()
      local bufname = vim.fn.bufname("#")
      if bufname == "" then
        return self:dispatch_refresh({ force_update = true })
      end
      if helper.is_protocol_uri(bufname) then
        return self:dispatch_refresh({ force_update = true })
      end
      return M.navigate( bufname, { filter = { self.win.bufname }, force_update = true })
    end,
    right         = view_cfg.win.right,
    title         = string.format(" %s ", self:getcwd()),
    title_pos     = view_cfg.win.title_pos,
    top           = view_cfg.win.top,
    user_autocmds = {
      ["DispatchRefresh"] = function()
        self:dispatch_refresh({ force_update = true })
      end,
    },
    user_mappings = self:action_wrap(usr_maps),
    width         = view_cfg.win.width,
    win_opts      = view_cfg.win.win_opts,
  }
  -- stylua: ignore end

  self.win:show()
end

---@return string
function Finder:getrwd()
  return util.select_n(1, helper.parse_protocol_uri(self.uri))
end

---@return string
function Finder:getcwd()
  return assert(self.files, "files is require").root_path
end

function Finder:cursor_node_entry()
  local entry
  vim.api.nvim_win_call(self.win.winid, function()
    local ref_id = helper.parse_ref_id(vim.api.nvim_get_current_line())
    if ref_id then
      entry = vim.deepcopy(self.files:node_entry(ref_id))
    end
  end)
  return entry
end

function Finder:close()
  if self.win then
    self.win:hide()
  end
end

function Finder:navigate(...)
  self.files:navigate(...)
end

-- Change `self.files` instance to provided directory path
---@param path string
function Finder:change_root(path)
  assert(path, "cannot change directory without path")
  assert(Path.new(path):is_directory(), "cannot change to non-directory path")

  self.watcher:disable(true)
  self.files = require("fyler.views.finder.files").new {
    path = path,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(path, ":t"),
    finder = self,
  }

  if self.win then
    self.win:update_title(string.format(" %s ", path))
  end

  return self
end

---@param opts { force_update: boolean, onrender: function }|nil
function Finder:dispatch_refresh(opts)
  opts = opts or {}

  -- Smart file system calculation, Use cache if not `opts.update` mentioned
  local get_table = async.wrap(function(onupdate)
    if opts.force_update then
      return self.files:update(function(_, this)
        onupdate(this:totable())
      end)
    end

    return onupdate(self.files:totable())
  end)

  async.void(function()
    local files_table = get_table()
    vim.schedule(function()
      require("fyler.views.finder.ui").files(files_table, function(component, options)
        self.win.ui:render(component, options, opts.onrender)
      end)
    end)
  end)
end

function Finder:clamp_cursor()
  local cur = vim.api.nvim_get_current_line()
  local ref_id = helper.parse_ref_id(cur)
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

local function run_mutation(operations)
  local async_handler = async.wrap(function(operation, _next)
    assert(require("fyler.lib.fs")[operation.type], "Unknown operation")(operation, _next)
    return operation.path or operation.dst
  end)

  local mutation_text_format = "Mutating (%d/%d)"
  local spinner = require("fyler.lib.spinner").new(string.format(mutation_text_format, 0, #operations))
  local last_focusable_operation = nil

  spinner:start()

  for i, operation in ipairs(operations) do
    local err = async_handler(operation)
    if err then
      vim.schedule_wrap(vim.notify)(err, vim.log.levels.ERROR, { title = "Fyler" })
    else
      last_focusable_operation = (operation.path or operation.dst) or last_focusable_operation
    end

    spinner:set_text(string.format(mutation_text_format, i, #operations))
  end

  spinner:stop()

  return last_focusable_operation
end

local CONFIRMATION_THRESHOLDS = { create = 5, delete = 0, move = 1, copy = 1 }

---@return boolean
local function can_skip_confirmation(operations)
  local count = { create = 0, delete = 0, move = 0, copy = 0 }
  util.tbl_each(operations, function(o)
    count[o.type] = (count[o.type] or 0) + 1
  end)

  -- stylua: ignore start
  return count.copy   <= CONFIRMATION_THRESHOLDS.copy
     and count.create <= CONFIRMATION_THRESHOLDS.create
     and count.delete <= CONFIRMATION_THRESHOLDS.delete
     and count.move   <= CONFIRMATION_THRESHOLDS.move
  -- stylua: ignore end
end

local get_confirmation = async.wrap(vim.schedule_wrap(function(...)
  require("fyler.input").confirm.open(...)
end))

local function should_mutate(operations, cwd)
  if config.values.views.finder.confirm_simple and can_skip_confirmation(operations) then
    return true
  end

  return get_confirmation(require("fyler.views.finder.ui").operations(util.tbl_map(operations, function(operation)
    local result = vim.deepcopy(operation)
    if operation.type == "create" or operation.type == "delete" then
      result.path = cwd:relative(operation.path)
    else
      result.src = cwd:relative(operation.src)
      result.dst = cwd:relative(operation.dst)
    end
    return result
  end)))
end

function Finder:dispatch_mutation()
  async.void(function()
    local operations = self.files:diff_with_lines(vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false))
    if vim.tbl_isempty(operations) then
      return self:dispatch_refresh()
    end

    if should_mutate(operations, require("fyler.lib.path").new(self:getcwd())) then
      M.navigate(run_mutation(operations), { force_update = true })
    end
  end)
end

local instances = {}

---@param uri string|nil
---@return Finder
function M.instance(uri)
  uri = assert(helper.normalize_uri(uri), "Faulty URI")

  local finder = instances[uri]
  if finder then
    return finder
  end

  local path = helper.parse_protocol_uri(uri) --[[@as string]]

  finder = Finder.new(uri)
  finder.watcher = require("fyler.views.finder.watcher").new(finder)
  finder.files = require("fyler.views.finder.files").new {
    open = true,
    path = path,
    type = "directory",
    name = Path.new(path):parent():posix_path(),
    finder = finder,
  }

  instances[uri] = finder
  return instances[uri]
end

---@param fn fun(uri: string)
function M.each_finder(fn)
  util.tbl_each(instances, fn)
end

---@param uri string|nil
---@param kind WinKind|nil
function M.open(uri, kind)
  M.instance(uri):open(kind or config.values.views.finder.win.kind)
end

local function _select(opts, handler)
  if opts.filter then
    util.tbl_each(opts.filter, function(uri)
      if helper.is_protocol_uri(uri) then
        handler(uri)
      end
    end)
  else
    M.each_finder(handler)
  end
end

M.close = vim.schedule_wrap(function(opts)
  _select(opts or {}, function(uri)
    M.instance(uri):close()
  end)
end)

---@param uri string|nil
---@param kind WinKind|nil
M.toggle = vim.schedule_wrap(function(uri, kind)
  local finder = M.instance(uri)
  if finder:isopen(kind) then
    finder:close()
  else
    finder:open(kind or config.values.views.finder.win.kind)
  end
end)

M.focus = vim.schedule_wrap(function(opts)
  _select(opts or {}, function(uri)
    M.instance(uri).win:focus()
  end)
end)

-- TODO: Can futher optimize by determining whether `files:navgiate` did any change or not?
---@param path string|nil
M.navigate = vim.schedule_wrap(function(path, opts)
  opts = opts or {}

  local set_cursor = vim.schedule_wrap(function(finder, ref_id)
    if finder:isopen() and ref_id then
      vim.api.nvim_win_call(finder.win.winid, function()
        vim.fn.search(string.format("/%05d ", ref_id))
      end)
    end
  end)

  _select(opts, function(uri)
    local finder = M.instance(uri)
    if not finder:isopen() then
      return
    end

    local update_table = async.wrap(function(...)
      finder.files:update(...)
    end)

    local navigate_path = async.wrap(function(...)
      finder:navigate(...)
    end)

    async.void(function()
      if opts.force_update then
        update_table()
      end

      local ref_id
      if path then
        ref_id = util.select_n(2, navigate_path(vim.fn.fnamemodify(Path.new(path):posix_path(), ":p")))
      end

      opts.onrender = function()
        set_cursor(finder, ref_id)
      end

      finder:dispatch_refresh(opts)
    end)
  end)
end)

return M
