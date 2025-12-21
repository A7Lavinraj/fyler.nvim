local Files = require "fyler.views.finder.files"
local Path = require "fyler.lib.path"
local Spinner = require "fyler.lib.spinner"
local Ui = require "fyler.lib.ui"
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
---@field bufnr integer
---@field bufname string
---@field namespace integer
---@field augroup integer
---@field ui Ui
---@field windows Win[]
local Finder = {}
Finder.__index = Finder

function Finder.new(dir)
  local files = Files.new {
    path = dir,
    open = true,
    type = "directory",
    name = vim.fn.fnamemodify(dir, ":t"),
  }

  local bufname = string.format("fyler://%s", dir)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, bufname)
  end

  local instance = {
    dir = dir,
    files = files,
    bufnr = bufnr,
    bufname = bufname,
    namespace = vim.api.nvim_create_namespace("fyler_finder_" .. bufnr),
    augroup = vim.api.nvim_create_augroup("fyler_finder_" .. bufnr, { clear = true }),
    windows = {},
  }
  instance.files.finder = instance

  setmetatable(instance, Finder)

  -- Create Ui instance (needs a win-like interface for rendering)
  instance.ui = Ui.new(instance)

  -- Set up buffer options and autocmds (once per Finder)
  instance:_setup_buffer()

  return instance
end

---@private
function Finder:_setup_buffer()
  local view = config.view("finder", config.values.views.finder.win.kind)

  -- Buffer options
  for option, value in pairs(view.win.buf_opts or {}) do
    util.set_buf_option(self.bufnr, option, value)
  end

  -- Buffer-local mappings
  local rev_maps = config.rev_maps "finder"
  local user_maps = config.user_maps "finder"
  local mappings_opts = view.mappings_opts or {}
  mappings_opts.buffer = self.bufnr

  local mappings = {
    [rev_maps["CloseView"]] = self:_action "n_close",
    [rev_maps["CollapseAll"]] = self:_action "n_collapse_all",
    [rev_maps["CollapseNode"]] = self:_action "n_collapse_node",
    [rev_maps["GotoCwd"]] = self:_action "n_goto_cwd",
    [rev_maps["GotoNode"]] = self:_action "n_goto_node",
    [rev_maps["GotoParent"]] = self:_action "n_goto_parent",
    [rev_maps["Select"]] = self:_action "n_select",
    [rev_maps["SelectSplit"]] = self:_action "n_select_split",
    [rev_maps["SelectTab"]] = self:_action "n_select_tab",
    [rev_maps["SelectVSplit"]] = self:_action "n_select_v_split",
  }

  for keys, callback in pairs(mappings) do
    for _, k in ipairs(util.tbl_wrap(keys)) do
      vim.keymap.set("n", k, callback, mappings_opts)
    end
  end

  for k, fn in pairs(user_maps) do
    vim.keymap.set("n", k, function()
      fn(self)
    end, mappings_opts)
  end

  -- Buffer autocmds
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = self.augroup,
    buffer = self.bufnr,
    callback = function()
      self:dispatch_refresh()
    end,
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = self.augroup,
    buffer = self.bufnr,
    callback = function()
      self:synchronize()
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self.augroup,
    buffer = self.bufnr,
    callback = function()
      self:constrain_cursor()
    end,
  })
  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = self.augroup,
    buffer = self.bufnr,
    callback = function()
      self:constrain_cursor()
    end,
  })

  -- User autocmds
  vim.api.nvim_create_autocmd("User", {
    pattern = "DispatchRefresh",
    group = self.augroup,
    callback = function()
      self:dispatch_refresh()
    end,
  })
end

--- Win-like interface for Ui rendering (Ui calls win:set_lines and win:set_extmark)
function Finder:set_lines(start, finish, lines)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end

  local was_modifiable = util.get_buf_option(self.bufnr, "modifiable")
  local undolevels = util.get_buf_option(self.bufnr, "undolevels")

  util.set_buf_option(self.bufnr, "modifiable", true)
  util.set_buf_option(self.bufnr, "undolevels", -1)

  vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace, 0, -1)
  vim.api.nvim_buf_set_lines(self.bufnr, start, finish, false, lines)

  if not was_modifiable then
    util.set_buf_option(self.bufnr, "modifiable", false)
  end

  util.set_buf_option(self.bufnr, "modified", false)
  util.set_buf_option(self.bufnr, "undolevels", undolevels)
end

function Finder:set_extmark(row, col, options)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, row, col, options)
  end
end

---@param name string
function Finder:_action(name)
  local action = require("fyler.views.finder.actions")[name]
  assert(action, string.format("action %s is not available", name))
  return action(self)
end

---@param kind WinKind
---@return Win
function Finder:add_window(kind)
  local view = config.view("finder", kind)

  local win
  win = Win.new {
    bufnr = self.bufnr,
    border = view.win.border,
    bottom = view.win.bottom,
    enter = true,
    footer = view.win.footer,
    footer_pos = view.win.footer_pos,
    height = view.win.height,
    kind = kind,
    left = view.win.left,
    on_show = function()
      indent.enable(win)
    end,
    on_hide = function()
      indent.disable(win)
    end,
    right = view.win.right,
    title = string.format(" %s ", self.dir),
    title_pos = view.win.title_pos,
    top = view.win.top,
    width = view.win.width,
    win_opts = view.win.win_opts,
  }

  win:show()
  table.insert(self.windows, win)

  -- Render on first show
  self:dispatch_refresh(function()
    local altbufnr = vim.fn.bufnr "#"
    if config.values.views.finder.follow_current_file and altbufnr ~= -1 then
      self:navigate(vim.api.nvim_buf_get_name(altbufnr))
    end
  end)

  return win
end

---@param win Win
function Finder:remove_window(win)
  -- Remove from list BEFORE hiding to prevent BufWinEnter recover() from finding it
  for i, w in ipairs(self.windows) do
    if w == win then
      table.remove(self.windows, i)
      break
    end
  end
  win:hide()
end

---@param tabid integer|nil
---@return Win|nil
function Finder:window_for_tab(tabid)
  tabid = tabid or vim.api.nvim_get_current_tabpage()
  for _, win in ipairs(self.windows) do
    if win:has_valid_winid() and vim.api.nvim_win_get_tabpage(win.winid) == tabid then
      return win
    end
  end
end

---@return Win|nil
function Finder:current_window()
  local winid = vim.api.nvim_get_current_win()
  for _, win in ipairs(self.windows) do
    if win.winid == winid then
      return win
    end
  end
end

--- Clean up invalid windows from list
function Finder:cleanup_invalid_windows()
  local valid = {}
  for _, win in ipairs(self.windows) do
    if win:has_valid_winid() then
      table.insert(valid, win)
    else
      win:hide()
    end
  end
  self.windows = valid
end

--- Legacy open method for compatibility
---@param kind WinKind
function Finder:open(kind)
  self:add_window(kind)
end

--- Close current window in this tab
function Finder:close()
  local win = self:window_for_tab()
  if win then
    self:remove_window(win)
  end
end

function Finder:exec_action(name, ...)
  local action = require("fyler.views.finder.actions")[name]
  assert(action, string.format("action %s is not available", name))
  action(self)(...)
end

function Finder:constrain_cursor()
  local cur = vim.api.nvim_get_current_line()
  local ref_id = parser.parse_ref_id(cur)
  if not ref_id then
    return
  end

  local _, ub = string.find(cur, ref_id)
  local win = self:current_window()
  if not win or not win:has_valid_winid() then
    return
  end

  local row, col = win:get_cursor()
  if not (row and col) then
    return
  end

  if col <= ub then
    win:set_cursor(row, ub + 1)
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
      self.ui:render(ui.files(files_table), function()
        if on_render then
          on_render()
        end

        -- TODO: I don't know why we need to reset syntax on entering fyler buffer with `:e`
        util.set_buf_option(self.bufnr, "syntax", "fyler")

        -- Rendering file tree with additional info
        ui.files_with_info(files_table, function(files_with_info_table)
          self.ui:render(files_with_info_table)
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
      local win = self:current_window() or self:window_for_tab()
      if not win or not win:has_valid_winid() then
        return
      end

      if not vim.api.nvim_buf_is_valid(self.bufnr) then
        return
      end

      for row, buf_line in ipairs(vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)) do
        if buf_line:find(ref_id) then
          win:set_cursor(row, 0)
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
    local buf_lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
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
  _finders = {}, ---@type table<string, Finder>
}

---@param dir string|nil
---@param kind WinKind|nil
---@return string, WinKind
local function compute_opts(dir, kind)
  return Path.new(dir or fs.cwd()):normalize(), kind or config.values.views.finder.win.kind
end

---@param tabid integer|nil
---@return Finder|nil, Win|nil
function M.finder_for_tab(tabid)
  tabid = tabid or vim.api.nvim_get_current_tabpage()
  for _, finder in pairs(M._finders) do
    for _, win in ipairs(finder.windows) do
      if win:has_valid_winid() and vim.api.nvim_win_get_tabpage(win.winid) == tabid then
        return finder, win
      end
    end
  end
end

---@param dir string
---@return Finder
function M.get_or_create_finder(dir)
  if not M._finders[dir] then
    M._finders[dir] = Finder.new(dir)
  end
  return M._finders[dir]
end

function M.open(dir, kind)
  dir, kind = compute_opts(dir, kind)
  local finder, win = M.finder_for_tab()

  if finder and win then
    -- Already open in this tab
    if finder.dir == dir then
      win:focus()
      return
    else
      -- Different dir requested, close current and open new
      finder:remove_window(win)
    end
  end

  local target_finder = M.get_or_create_finder(dir)
  target_finder:add_window(kind)
end

function M.close()
  local finder, win = M.finder_for_tab()
  if finder and win then
    finder:remove_window(win)
  end
end

function M.toggle(dir, kind)
  local finder, win = M.finder_for_tab()
  if finder and win then
    M.close()
  else
    M.open(dir, kind)
  end
end

function M.focus()
  local finder, win = M.finder_for_tab()
  if finder and win then
    win:focus()
  else
    M.open()
  end
end

---@param path string|nil
function M.navigate(path)
  local finder, _ = M.finder_for_tab()
  if not path or not finder or parser.is_protocol_path(path) then
    return
  end

  finder:navigate(Path.new(path):normalize())
end

function M.recover()
  local finder, win = M.finder_for_tab()
  if not finder or not win then
    return
  end

  -- Check if the window is still showing the fyler buffer
  if win:has_valid_winid() then
    local win_buf = vim.api.nvim_win_get_buf(win.winid)
    if win_buf == finder.bufnr then
      return -- Still valid, nothing to recover
    end
  end

  -- Window is showing different buffer or invalid, remove it
  win:recover()
  finder:remove_window(win)
end

function M.load(url)
  local dir0 = (url:gsub(vim.pesc "fyler://", ""))
  local dir, kind = compute_opts(dir0)

  local finder, win = M.finder_for_tab()

  if finder and win then
    if finder.dir == dir then
      -- Already showing this directory
      return
    else
      -- Close current, open new
      finder:remove_window(win)
    end
  end

  local target_finder = M.get_or_create_finder(dir)
  target_finder:add_window(kind)
end

return M
