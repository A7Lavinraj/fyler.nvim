local util = require "fyler.lib.util"

---@alias WinKind
---| "float"
---| "replace"
---| "split_above"
---| "split_above_all"
---| "split_below"
---| "split_below_all"
---| "split_left"
---| "split_left_most"
---| "split_right"
---| "split_right_most"

---@class Win
---@field augroup integer
---@field autocmds table
---@field border string|string[]
---@field bottom string|nil
---@field buf_opts table
---@field bufname string
---@field bufnr integer|nil
---@field enter boolean
---@field footer string|string[]|nil
---@field footer_pos string|nil
---@field height string
---@field kind WinKind
---@field left string|nil
---@field mappings table
---@field namespace integer
---@field old_bufnr integer|nil
---@field old_winid integer|nil
---@field on_hide function|nil
---@field on_show function|nil
---@field render function|nil
---@field right string|nil
---@field title string|string[]|nil
---@field title_pos string|nil
---@field top string|nil
---@field ui Ui
---@field user_autocmds table
---@field user_mappings table
---@field width string
---@field win_opts table
---@field winid integer|nil
local Win = {}
Win.__index = Win

---@return Win
function Win.new(opts)
  opts = opts or {}

  local instance = util.tbl_merge_keep(opts, { kind = "float" })
  instance.ui = require("fyler.lib.ui").new(instance)
  setmetatable(instance, Win)

  return instance
end

---@return boolean
function Win:has_valid_winid()
  return type(self.winid) == "number" and vim.api.nvim_win_is_valid(self.winid)
end

---@return boolean
function Win:has_valid_bufnr()
  return type(self.bufnr) == "number" and vim.api.nvim_buf_is_valid(self.bufnr)
end

---@return boolean
function Win:is_visible()
  return self:has_valid_winid() and self:has_valid_bufnr()
end

---@return integer|nil
function Win:winbuf()
  if self:has_valid_winid() then
    return vim.api.nvim_win_get_buf(self.winid)
  end
end

---@return integer|nil, integer|nil
function Win:get_cursor()
  if not self:has_valid_winid() then
    return
  end

  return util.unpack(vim.api.nvim_win_get_cursor(self.winid))
end

---@param row integer
---@param col integer
function Win:set_cursor(row, col)
  if self:has_valid_winid() then
    vim.api.nvim_win_set_cursor(self.winid, { row, col })
  end
end

function Win:focus()
  local windows = vim.fn.win_findbuf(self.bufnr)
  if not windows or not windows[1] then
    return
  end

  self.old_winid = vim.api.nvim_get_current_win()
  self.old_bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_set_current_win(windows[1])
end

function Win:update_config(config)
  if not self:has_valid_winid() then
    return
  end

  local old_config = vim.api.nvim_win_get_config(self.winid)

  vim.api.nvim_win_set_config(self.winid, util.tbl_merge_force(old_config, config))
end

function Win:update_title(title)
  if self.kind:match "^float" then
    self:update_config { title = title }
  end
end

function Win:config()
  local winconfig = {
    style = "minimal",
  }

  ---@param str string
  local function destructure(str)
    if not str:match "[%d%.]+[%a]+" then
      return 0, 0
    end
    local v, u = string.match(str, "([%d%.]+)([%a]+)")
    return tonumber(v), u
  end

  if self.kind:match "^split_" then
    winconfig.split = self.kind:match "^split_(.*)"
  elseif self.kind:match "^replace" then
    return winconfig
  elseif self.kind:match "^float" then
    winconfig.relative = "editor"
    winconfig.border = self.border
    winconfig.title = self.title
    winconfig.title_pos = self.title_pos
    winconfig.footer = self.footer
    winconfig.footer_pos = self.footer_pos
    winconfig.row = 0
    winconfig.col = 0

    if self.top and self.top ~= "none" then
      local value, unit = destructure(self.top)
      if unit == "rel" then
        winconfig.row = math.ceil(value * vim.o.lines)
      elseif unit == "abs" then
        winconfig.row = value
      else
        error(string.format("[fyler.nvim] Unknown unit '%s'", unit))
      end
    end

    if self.right and self.right ~= "none" then
      local rv, ru = destructure(self.right)
      local wv = destructure(self.width)
      if ru == "rel" then
        winconfig.col = math.ceil((1 - rv - wv) * vim.o.columns)
      elseif ru == "abs" then
        winconfig.col = (vim.o.columns - rv - wv)
      else
        error(string.format("[fyler.nvim] Unknown unit '%s'", ru))
      end
    end

    if self.bottom and self.bottom ~= "none" then
      local value, unit = destructure(self.bottom)
      local hv = destructure(self.height)
      if unit == "rel" then
        winconfig.row = math.ceil((1 - value - hv) * vim.o.lines)
      elseif unit == "abs" then
        winconfig.row = (vim.o.lines - value - hv)
      else
        error(string.format("[fyler.nvim] Unknown unit '%s'", unit))
      end
    end

    if self.left and self.left ~= "none" then
      local value, unit = destructure(self.left)
      if unit == "rel" then
        winconfig.col = math.ceil(value * vim.o.columns)
      elseif unit == "abs" then
        winconfig.col = value
      else
        error(string.format("[fyler.nvim] Unknown unit '%s'", unit))
      end
    end
  else
    error(string.format("[fyler.nvim] Invalid window kind `%s`", self.kind))
  end

  if self.width then
    local value, unit = destructure(self.width)
    if unit == "rel" then
      winconfig.width = math.ceil(value * vim.o.columns)
    elseif unit == "abs" then
      winconfig.width = value
    else
      error(string.format("[fyler.nvim] Unknown unit '%s'", unit))
    end
  end

  if self.height then
    local value, unit = destructure(self.height)
    if unit == "rel" then
      winconfig.height = math.ceil(value * vim.o.lines)
    elseif unit == "abs" then
      winconfig.height = value
    else
      error(string.format("[fyler.nvim] Unknown unit '%s'", unit))
    end
  end

  return winconfig
end

function Win:show()
  if self:has_valid_winid() then
    return
  end

  -- Saving alternative "bufnr" and "winid" for later use
  self.old_bufnr = vim.api.nvim_get_current_buf()
  self.old_winid = vim.api.nvim_get_current_win()

  self.bufnr = vim.api.nvim_create_buf(false, true)
  if self.bufname then
    vim.api.nvim_buf_set_name(self.bufnr, self.bufname)
  end

  local win_config = self:config()
  if win_config.split and (win_config.split:match "_all$" or win_config.split:match "_most$") then
    if win_config.split == "left_most" then
      vim.api.nvim_command(string.format("topleft %dvsplit", win_config.width))
    elseif win_config.split == "above_all" then
      vim.api.nvim_command(string.format("topleft %dsplit", win_config.height))
    elseif win_config.split == "right_most" then
      vim.api.nvim_command(string.format("botright %dvsplit", win_config.width))
    elseif win_config.split == "below_all" then
      vim.api.nvim_command(string.format("botright %dsplit", win_config.height))
    else
      error(string.format("Invalid window kind `%s`", win_config.split))
    end

    self.winid = vim.api.nvim_get_current_win()
    if not self.enter then
      vim.api.nvim_set_current_win(self.old_winid)
    end

    vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  elseif self.kind:match "^replace" then
    self.winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  else
    self.winid = vim.api.nvim_open_win(self.bufnr, self.enter, win_config)

    -- Trigger "BufEnter" event to focus buffer for floating window when "enter" enabled
    -- [IMPORTANT]: This is necessary because "self.winid" will not get set on time to automatically triggered.
    if self.enter then
      vim.api.nvim_exec_autocmds("BufEnter", {})
    end
  end

  if self.on_show then
    self.on_show()
  end

  self.augroup = vim.api.nvim_create_augroup("Fyler-augroup-" .. self.bufnr, { clear = true })
  self.namespace = vim.api.nvim_create_namespace("Fyler-namespace-" .. self.bufnr)

  for keys, v in pairs(self.mappings or {}) do
    for _, k in ipairs(util.tbl_wrap(keys)) do
      vim.keymap.set("n", k, v, { buffer = self.bufnr, silent = true, noremap = true })
    end
  end

  for k, v in pairs(self.user_mappings or {}) do
    vim.keymap.set("n", k, v, { buffer = self.bufnr, silent = true, noremap = true })
  end

  for option, value in pairs(self.win_opts or {}) do
    util.set_win_option(self.winid, option, value)
  end

  for option, value in pairs(self.buf_opts or {}) do
    util.set_buf_option(self.bufnr, option, value)
  end

  for event, callback in pairs(self.autocmds or {}) do
    vim.api.nvim_create_autocmd(event, { group = self.augroup, buffer = self.bufnr, callback = callback })
  end

  for event, callback in pairs(self.user_autocmds or {}) do
    vim.api.nvim_create_autocmd("User", { pattern = event, group = self.augroup, callback = callback })
  end

  if self.render then
    self.render()
  end
end

function Win:clear()
  vim.api.nvim_clear_autocmds { group = self.augroup }
end

function Win:hide()
  self:clear()

  -- Recover alternate buffer if using "replace"|"split" window kind
  if self.kind:match "^replace" then
    if
      util.is_valid_winid(self.winid)
      and util.is_valid_bufnr(self.old_bufnr)
      and vim.api.nvim_buf_is_loaded(self.old_bufnr)
    then
      util.try(vim.api.nvim_win_set_buf, self.winid, self.old_bufnr)
    end

    util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  else
    util.try(vim.api.nvim_win_close, self.winid, true)
    util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  end

  self.winid = nil
  self.bufnr = nil

  if self.on_hide then
    self.on_hide()
  end
end

-- Handle case when user open a NON FYLER BUFFER in "Fyler" window
function Win:recover()
  self:clear()

  if self.kind:match "^replace" or self.kind:match "^split" then
    util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  else
    local cached_bufnr = vim.api.nvim_get_current_buf()
    util.try(vim.api.nvim_win_close, self.winid, true)
    util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })

    if util.is_valid_winid(self.old_winid) then
      vim.api.nvim_win_set_buf(self.old_winid, cached_bufnr)
      vim.api.nvim_set_current_win(self.old_winid)
    end
  end
end

return Win
