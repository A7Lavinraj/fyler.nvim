local config = require "fyler.config"
local fs = require "fyler.lib.fs"
local fyler = require "fyler"
local parser = require "fyler.views.finder.parser"

local M = {}

function M.n_close()
  return fyler.close
end

-- NOTE: Dependency injection due to shared logic between select actions
---@param self Finder
---@param opener fun(path: string)
local function _select(self, opener)
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

  local function open_in_window(winid)
    winid = winid or self.win.winid
    vim.api.nvim_set_current_win(winid)
    opener(entry.path)
  end

  -- Close if kind=replace|float or config.values.views.finder.close_on_select is enabled
  local should_close = self.win.kind:match "^replace"
    or self.win.kind:match "^float"
    or config.values.views.finder.close_on_select

  if should_close then
    self:exec_action "n_close"
    open_in_window(vim.api.nvim_get_current_win())
  else
    -- For split variants, we should pick windows
    config.winpick_provider({ self.win.winid }, open_in_window, config.winpick_opts)
  end
end

function M.n_select_tab(self)
  return function()
    _select(self, function(path)
      vim.cmd.tabedit { args = { path }, mods = { keepalt = false } }
    end)
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

    self:chdir(parent_dir)
    self:dispatch_refresh()
  end
end

---@param self Finder
function M.n_goto_cwd(self)
  return function()
    if self.dir == fs.cwd() then
      return
    end

    self:chdir(fs.cwd())
    self:dispatch_refresh()
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
      self:chdir(entry.path)
      self:dispatch_refresh()
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
      if not self.win:has_valid_winid() then
        return
      end

      local marker = string.format("/%05d", focus_ref_id)
      local lines = vim.api.nvim_buf_get_lines(self.win.bufnr, 0, -1, false)

      for ln, line in ipairs(lines) do
        if line:find(marker, 1, true) then
          vim.api.nvim_win_set_cursor(self.win.winid, { ln, 0 })
          break
        end
      end
    end)
  end
end

return M
