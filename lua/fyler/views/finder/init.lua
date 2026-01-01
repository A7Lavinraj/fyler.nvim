local async = require "fyler.lib.async"
local config = require "fyler.config"
local util = require "fyler.lib.util"

local M = {}

---@class Finder
---@field dir string      : Home directory local to instance
---@field tab string      : Tab ID
---@field files Files     : Tree state local to instance
---@field watcher Watcher : Tree state local to instance
local Finder = {}
Finder.__index = Finder

---@param dir string   : Home directory local to instance
---@param tab string   : Tab ID
function Finder.new(dir, tab)
  local instance = {}
  instance._tag = 0
  instance._cache = {}

  instance.dir = dir
  instance.tab = tab
  return setmetatable(instance, Finder)
end

---@param name string : Name of corresponding available action
function Finder:_action(name)
  local action = require("fyler.views.finder.actions")[name]
  return assert(action, string.format("action %s is not available", name))(self)
end

-- Converts string to function mapping into an action
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

-- Action caller
---@param name string : Name of available action
---@param ... any     : Optional action arguments
function Finder:exec_action(name, ...)
  self:_action(name)(...)
end

---@param bufname string : Buffer name from which finder should load or create new
---@param kind WinKind   : Kind of the finder window
function Finder:open(bufname, kind)
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
    bufname       = bufname,
    bottom        = view_cfg.win.bottom,
    buf_opts      = view_cfg.win.buf_opts,
    enter         = true,
    footer        = view_cfg.win.footer,
    footer_pos    = view_cfg.win.footer_pos,
    height        = view_cfg.win.height,
    kind          = kind,
    left          = view_cfg.win.left,
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
    mappings_opts = view_cfg.mappings_opts,
    on_show       = function() indent.attach(self.win) end,
    on_hide       = function() indent.detach(self.win) end,
    render        = function()
      local bufname = vim.fn.bufname("#")
      if bufname == "" or util.is_protocol_uri(bufname) then
        return self:dispatch_refresh({ force_update = true })
      end

      return M.navigate(bufname, {
        filter = { self.win.bufname },
        force_refresh = true,
      })
    end,
    right         = view_cfg.win.right,
    title         = string.format(" %s ", self:getcwd()),
    title_pos     = view_cfg.win.title_pos,
    top           = view_cfg.win.top,
    user_autocmds = {
      ["DispatchRefresh"] = function() self:dispatch_refresh() end,
    },
    user_mappings = self:_action_mod(usr_maps),
    width         = view_cfg.win.width,
    win_opts      = view_cfg.win.win_opts,
  }
  -- stylua: ignore end

  self.watcher:enable()
  self.win:show()
end

---@return string
function Finder:getcwd()
  return assert(self.files, "files is require").root_path
end

function Finder:cursor_node_entry()
  local entry
  vim.api.nvim_win_call(self.win.winid, function()
    local ref_id = util.parse_ref_id(vim.api.nvim_get_current_line())
    if ref_id then
      entry = vim.deepcopy(self.files:node_entry(ref_id))
    end
  end)
  return entry
end

function Finder:close()
  if self.win then
    self.watcher:disable()
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
  assert(vim.fn.isdirectory(path) == 1, "cannot change to non-directory path")

  self.watcher:disable()
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
  local ref_id = util.parse_ref_id(cur)
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

local function wrapper(module)
  return setmetatable({}, {
    __index = function(_, k)
      return async.wrap(function(...)
        module[k](...)
      end)
    end,
  })
end

local wfs, wtrash = wrapper(require "fyler.lib.fs"), wrapper(require "fyler.lib.trash")
local function get_operation_handlers()
  return {
    create = function(op)
      wfs.create(op.path, op.entry_type == "directory")
      return op.path
    end,
    delete = function(op)
      if config.values.views.finder.delete_to_trash then
        wtrash.dump(op.path)
      else
        wfs.delete(op.path)
      end
      return nil
    end,
    move = function(op)
      wfs.move(op.src, op.dst)
      return op.dst
    end,
    copy = function(op)
      wfs.copy(op.src, op.dst)
      return op.dst
    end,
  }
end

local function run_mutation(operations)
  local MUTATION_TEXT_FORMAT = "Mutating (%d)/(%d)"
  local handlers = get_operation_handlers()
  local spinner = require("fyler.lib.spinner").new(string.format(MUTATION_TEXT_FORMAT, 0, #operations))
  local last_focusable_operation = nil

  spinner:start()

  for i, operation in ipairs(operations) do
    local handler = handlers[operation.type]
    if handler then
      last_focusable_operation = handler(operation) or last_focusable_operation
    end

    spinner:set_text(string.format(MUTATION_TEXT_FORMAT, i, #operations))
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
      M.navigate(run_mutation(operations) or "", { force_update = true, force_refresh = true })
    end
  end)
end

---@param uri string|nil
---@return string
local function normalize_uri(uri)
  local fs = require "fyler.lib.fs"
  local dir, tab = nil, nil
  if not uri or uri == "" then
    dir = fs.cwd()
    tab = tostring(vim.api.nvim_get_current_tabpage())
  elseif util.is_protocol_uri(uri) then
    dir, tab = util.parse_protocol_uri(uri)
    dir = dir or fs.cwd()
    tab = tab or tostring(vim.api.nvim_get_current_tabpage())
  else
    dir = uri
    tab = tostring(vim.api.nvim_get_current_tabpage())
  end

  return util.build_protocol_uri(dir, tab)
end

local Manager = {
  states = setmetatable({}, {
    __index = function(t, k)
      local v = {}
      rawset(t, k, v)
      return v
    end,
  }),
}

function Manager:find_by_win(winid)
  if not util.is_valid_winid(winid) then
    return
  end

  for tab, dirs in pairs(self.states) do
    for dir, finder in pairs(dirs) do
      if finder.win and finder.win:has_valid_winid() and finder.win.winid == winid then
        return finder, dir, tab
      end
    end
  end
end

function Manager:first_visible()
  for tab, dirs in pairs(self.states) do
    for dir, finder in pairs(dirs) do
      if finder.win and finder.win:has_valid_winid() then
        return finder, dir, tab
      end
    end
  end
end

---@param uri string
---@return Finder
function Manager:get(uri)
  local dir, tab = util.parse_protocol_uri(uri)
  assert(dir, "Directory is required")
  assert(tab, "Tab is required")
  assert(config, "Config is required")

  local finder = self.states[tab][dir]
  if not finder then
    finder = Finder.new(dir, tab)
    finder.watcher = require("fyler.views.finder.watcher").register(finder)
    finder.files = require("fyler.views.finder.files").new {
      path = dir,
      open = true,
      type = "directory",
      name = vim.fn.fnamemodify(dir, ":t"),
      finder = finder,
    }

    self.states[tab][dir] = finder
  end

  return finder
end

---@param callback fun(finder: Finder, dir: string, tab: number)
function Manager:each(callback)
  for tab, dirs in pairs(self.states) do
    for dir, finder in pairs(dirs) do
      callback(finder, dir, tab)
    end
  end
end


---@param uri string|nil
---@param kind WinKind|nil
function M.open(uri, kind)
  local normalized_uri = normalize_uri(uri)
  Manager:get(normalized_uri):open(normalized_uri, kind or config.values.views.finder.win.kind)
end

function M.get_current_dir()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local current_win = vim.api.nvim_get_current_win()

  -- 1. Prefer the finder attached to the current window.
  local finder = Manager:find_by_win(current_win)
  if finder and finder.win and finder.win:has_valid_winid() then
    return finder:getcwd()
  end

  -- 2. Fallback to any finder visible in the current tab.
  local wins_in_tab = vim.api.nvim_tabpage_list_wins(current_tab)
  for _, winid in ipairs(wins_in_tab) do
    local tab_finder = Manager:find_by_win(winid)
    if tab_finder and tab_finder.win and tab_finder.win:has_valid_winid() then
      return tab_finder:getcwd()
    end
  end

  -- 3. As a last resort, return the directory of the first visible finder.
  local first_visible = Manager:first_visible()
  if first_visible and first_visible.win and first_visible.win:has_valid_winid() then
    return first_visible:getcwd()
  end

  return vim.loop.cwd()
end

local function _select(opts, handler)
  if opts.filter then
    util.tbl_each(opts.filter, function(uri)
      if util.is_protocol_uri(uri) then
        handler(uri)
      end
    end)
  else
    Manager:each(function(_, dir, tab)
      handler(util.build_protocol_uri(dir, tab))
    end)
  end
end

M.close = vim.schedule_wrap(function(opts)
  opts = opts or {}
  _select(opts, function(uri)
    Manager:get(uri):close()
  end)
end)

---@param uri string|nil
---@param kind WinKind|nil
M.toggle = vim.schedule_wrap(function(uri, kind)
  local normalized_uri = normalize_uri(uri)
  local finder = Manager:get(normalized_uri)
  if finder.win and finder.win:has_valid_bufnr() then
    finder:close()
  else
    finder:open(normalized_uri, kind or config.values.views.finder.win.kind)
  end
end)

M.focus = vim.schedule_wrap(function(opts)
  opts = opts or {}
  _select(opts, function(uri)
    Manager:get(uri).win:focus()
  end)
end)

-- TODO: Can futher optimize by determining whether `files:navgiate` did any change or not?
---@param path string|nil
M.navigate = vim.schedule_wrap(function(path, opts)
  opts = opts or {}
  if not path then
    return
  end

  local set_cursor = vim.schedule_wrap(function(finder, ref_id)
    if finder.win:has_valid_winid() and ref_id then
      vim.api.nvim_win_call(finder.win.winid, function()
        vim.fn.search(string.format("/%05d ", ref_id))
      end)
    end
  end)

  _select(opts, function(uri)
    local finder = Manager:get(uri)
    if not (finder and finder.win:has_valid_winid() and finder.win:has_valid_bufnr()) then
      return
    end

    local target_path = require("fyler.lib.path").new(path):normalize()
    local node_entry = finder:cursor_node_entry()
    if node_entry and node_entry.path == target_path then
      return
    end

    local update_table = async.wrap(function(...)
      finder.files:update(...)
    end)

    async.void(function()
      if opts.force_update then
        update_table()
      end

      finder:navigate(target_path, function(_, ref_id)
        if not opts.force_refresh then
          return set_cursor(finder, ref_id)
        end

        return finder:dispatch_refresh {
          onrender = function()
            set_cursor(finder, ref_id)
          end,
        }
      end)
    end)
  end)
end)

return M
