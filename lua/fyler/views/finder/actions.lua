local config = require "fyler.config"
local fs = require "fyler.lib.fs"
local fyler = require "fyler"
local parser = require "fyler.views.finder.parser"

local M = {}

function M.n_close()
  return fyler.close
end

---@class fyler.views.finder.actions.select_opts
---@field winpick? boolean Whether to use winpick to select the file (default: true)

-- NOTE: Dependency injection due to shared logic between select actions
---@param self Finder
---@param opener fun(path: string)
---@param opts? fyler.views.finder.actions.select_opts
local function _select(self, opener, opts)
  opts = vim.tbl_extend("force", { winpick = true }, opts or {})

  local ref_id = parser.parse_ref_id(vim.api.nvim_get_current_line())
  if not ref_id then
    return
  end

  local entry = self.files:node_entry(ref_id)
  if not entry then
    return
  end

  if entry:is_directory() then
    if entry.open then
      self.files:collapse_node(ref_id)
    else
      self.files:expand_node(ref_id)
    end
    self:dispatch_refresh()
    return
  end

  local win = self:current_window()
  if not win then
    return
  end

  local function open_in_window(winid)
    if not winid then
      return
    end
    vim.api.nvim_set_current_win(winid)
    opener(entry.path)
  end

  -- Close if kind=replace|float or config.values.views.finder.close_on_select is enabled
  local should_close = win.kind:match "^replace"
    or win.kind:match "^float"
    or config.values.views.finder.close_on_select

  if should_close then
    self:exec_action "n_close"
    open_in_window(vim.api.nvim_get_current_win())
  elseif opts.winpick then
    -- For split variants, we should pick windows
    config.winpick_provider({ win.winid }, open_in_window, config.winpick_opts)
  else
    opener(entry.path)
  end
end

function M.n_select_tab(self)
  return function()
    _select(self, function(path)
      vim.cmd.tabedit { args = { path }, mods = { keepalt = false } }
    end, { winpick = false })
  end
end

function M.n_select_v_split(self)
  return function()
    _select(self, function(path)
      vim.cmd.vsplit { args = { path }, mods = { keepalt = false } }
    end)
  end
end

function M.n_select_split(self)
  return function()
    _select(self, function(path)
      vim.cmd.split { args = { path }, mods = { keepalt = false } }
    end)
  end
end

function M.n_select(self)
  return function()
    _select(self, function(path)
      vim.cmd.edit { args = { vim.fn.fnameescape(path) }, mods = { keepalt = false } }
    end)
  end
end

---@param self Finder
function M.n_collapse_all(self)
  return function()
    self.files:collapse_all()
    self:dispatch_refresh()
  end
end

---@param self Finder
function M.n_goto_parent(self)
  return function()
    local parent_dir = vim.fn.fnamemodify(self.dir, ":h")
    if parent_dir == self.dir then
      return
    end

    local win = self:current_window()
    local kind = win and win.kind or nil

    -- Open parent directory (this will close current window and open new Finder)
    local finder_module = require "fyler.views.finder"
    finder_module.open(parent_dir, kind)
  end
end

---@param self Finder
function M.n_goto_cwd(self)
  return function()
    if self.dir == fs.cwd() then
      return
    end

    local win = self:current_window()
    local kind = win and win.kind or nil

    -- Open cwd (this will close current window and open new Finder)
    local finder_module = require "fyler.views.finder"
    finder_module.open(fs.cwd(), kind)
  end
end

---@param self Finder
function M.n_goto_node(self)
  return function()
    local ref_id = parser.parse_ref_id(vim.api.nvim_get_current_line())
    if not ref_id then
      return
    end

    local entry = self.files:node_entry(ref_id)
    if not entry then
      return
    end

    if entry:is_directory() then
      local win = self:current_window()
      local kind = win and win.kind or nil

      -- Open directory (this will close current window and open new Finder)
      local finder_module = require "fyler.views.finder"
      finder_module.open(entry.path, kind)
    else
      M.n_select(self)()
    end
  end
end

---@param self Finder
function M.n_collapse_node(self)
  return function()
    local ref_id = parser.parse_ref_id(vim.api.nvim_get_current_line())
    if not ref_id then
      return
    end

    local entry = self.files:node_entry(ref_id)
    if not entry then
      return
    end

    -- should not collapse root, so get it's id
    local root_ref_id = self.files.trie.value
    if entry:is_directory() and ref_id == root_ref_id then
      return
    end

    local collapse_target = self.files:find_parent(ref_id)
    if (not collapse_target) or (not entry.open) and collapse_target == root_ref_id then
      return
    end

    local focus_ref_id
    if entry:is_directory() and entry.open then
      self.files:collapse_node(ref_id)
      focus_ref_id = ref_id
    else
      self.files:collapse_node(collapse_target)
      focus_ref_id = collapse_target
    end

    self:dispatch_refresh(function()
      local win = self:current_window() or self:window_for_tab()
      if not win or not win:has_valid_winid() then
        return
      end

      local marker = string.format("/%05d", focus_ref_id)
      local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)

      for ln, line in ipairs(lines) do
        if line:find(marker, 1, true) then
          vim.api.nvim_win_set_cursor(win.winid, { ln, 0 })
          break
        end
      end
    end)
  end
end

return M
