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
---@field bottom integer|string|nil
---@field bufnr integer
---@field enter boolean
---@field footer string|string[]|nil
---@field footer_pos string|nil
---@field height string
---@field kind WinKind
---@field left integer|string|nil
---@field namespace integer
---@field on_hide function|nil
---@field on_show function|nil
---@field right integer|string|nil
---@field title string|string[]|nil
---@field title_pos string|nil
---@field top integer|string|nil
---@field user_autocmds table
---@field width integer|string
---@field win integer|nil
---@field win_opts table
---@field winid integer|nil
local Win = {}
Win.__index = Win

---@return Win
function Win.new(opts)
  opts = opts or {}

  local instance = util.tbl_merge_keep(opts, { kind = "float" })
  setmetatable(instance, Win)

  return instance
end

---@return boolean
function Win:has_valid_winid()
  return type(self.winid) == "number" and vim.api.nvim_win_is_valid(self.winid)
end

---@return boolean
function Win:is_visible()
  return self:has_valid_winid()
end

---@return integer|nil, integer|nil
function Win:get_cursor()
  if not self:has_valid_winid() then
    return
  end

  return util.unpack(vim.api.nvim_win_get_cursor(self.winid))
end

function Win:set_local_buf_option(k, v)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    util.set_buf_option(self.bufnr, k, v)
  end
end

function Win:set_local_win_option(k, v)
  if self:has_valid_winid() then
    util.set_win_option(self.winid, k, v)
  end
end

function Win:get_local_buf_option(k)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    return util.get_buf_option(self.bufnr, k)
  end
end

function Win:get_local_win_option(k)
  if self:has_valid_winid() then
    return util.get_win_option(self.winid, k)
  end
end

---@param row integer
---@param col integer
function Win:set_cursor(row, col)
  if self:has_valid_winid() then
    vim.api.nvim_win_set_cursor(self.winid, { row, col })
  end
end

function Win:focus()
  if self:has_valid_winid() then
    vim.api.nvim_set_current_win(self.winid)
  end
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

  ---@param dim integer|string
  ---@return integer|nil, boolean|nil
  local function resolve_dim(dim)
    if type(dim) == "number" then
      return dim, false
    elseif type(dim) == "string" then
      local is_percentage = dim:match "%%$"
      if is_percentage then
        return tonumber(dim:match "^(.*)%%$") * 0.01, true
      else
        return tonumber(dim), false
      end
    end
  end

  if self.kind:match "^split_" then
    winconfig.split = self.kind:match "^split_(.*)"
  elseif self.kind:match "^replace" then
    return winconfig
  elseif self.kind:match "^float" then
    winconfig.relative = self.win and "win" or "editor"
    winconfig.border = self.border
    winconfig.title = self.title
    winconfig.title_pos = self.title_pos
    winconfig.footer = self.footer
    winconfig.footer_pos = self.footer_pos
    winconfig.row = 0
    winconfig.col = 0
    winconfig.win = self.win

    if not (not self.top and self.top == "none") then
      local magnitude, is_percentage = resolve_dim(self.top)
      if is_percentage then
        winconfig.row = math.ceil(magnitude * vim.o.lines)
      else
        winconfig.row = magnitude
      end
    end

    if not (not self.right or self.right == "none") then
      local right_magnitude, is_percentage = resolve_dim(self.right)
      local width_magnitude = resolve_dim(self.width)
      if is_percentage then
        winconfig.col = math.ceil((1 - right_magnitude - width_magnitude) * vim.o.columns)
      else
        winconfig.col = (vim.o.columns - right_magnitude - width_magnitude)
      end
    end

    if not (not self.bottom or self.bottom == "none") then
      local bottom_magnitude, is_percentage = resolve_dim(self.bottom)
      local height_magnitude = resolve_dim(self.height)
      if is_percentage then
        winconfig.row = math.ceil((1 - bottom_magnitude - height_magnitude) * vim.o.lines)
      else
        winconfig.row = (vim.o.lines - bottom_magnitude - height_magnitude)
      end
    end

    if not (not self.left and self.left == "none") then
      local magnitude, is_percentage = resolve_dim(self.left)
      if is_percentage then
        winconfig.col = math.ceil(magnitude * vim.o.columns)
      else
        winconfig.col = magnitude
      end
    end
  else
    error(string.format("[fyler.nvim] Invalid window kind `%s`", self.kind))
  end

  if self.width then
    local magnitude, is_percentage = resolve_dim(self.width)
    if is_percentage then
      winconfig.width = math.ceil(magnitude * vim.o.columns)
    else
      winconfig.width = magnitude
    end
  end

  if self.height then
    local magnitude, is_percentage = resolve_dim(self.height)
    if is_percentage then
      winconfig.height = math.ceil(magnitude * vim.o.lines)
    else
      winconfig.height = magnitude
    end
  end

  return winconfig
end

function Win:show()
  if self:has_valid_winid() then
    return
  end

  local win_config = self:config()
  local current_win = vim.api.nvim_get_current_win()

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
      vim.api.nvim_set_current_win(current_win)
    end

    vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  elseif self.kind:match "^replace" then
    self.winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  else
    self.winid = vim.api.nvim_open_win(self.bufnr, self.enter, win_config)
  end

  if self.on_show then
    self.on_show()
  end

  self.augroup = vim.api.nvim_create_augroup("fyler_augroup_win_" .. self.winid, { clear = true })
  self.namespace = vim.api.nvim_create_namespace("fyler_namespace_win_" .. self.winid)

  for option, value in pairs(self.win_opts or {}) do
    util.set_win_option(self.winid, option, value)
  end

  for event, callback in pairs(self.autocmds or {}) do
    vim.api.nvim_create_autocmd(event, { group = self.augroup, buffer = self.bufnr, callback = callback })
  end

  for event, callback in pairs(self.user_autocmds or {}) do
    vim.api.nvim_create_autocmd("User", { pattern = event, group = self.augroup, callback = callback })
  end
end

function Win:hide()
  vim.api.nvim_clear_autocmds { group = self.augroup }

  if self.kind:match "^replace" then
    local altbufnr = vim.fn.bufnr "#"
    if altbufnr == -1 then
      util.try(vim.cmd.enew)
    else
      util.try(vim.api.nvim_win_set_buf, self.winid, altbufnr)
    end
  else
    util.try(vim.api.nvim_win_close, self.winid, true)
  end

  if self.on_hide then
    self.on_hide()
  end
end

-- Handle case when user open a NON FYLER BUFFER in "Fyler" window
function Win:recover()
  vim.api.nvim_clear_autocmds { group = self.augroup }

  if not (self.kind:match "^replace" or self.kind:match "^split") then
    local current_bufnr = vim.api.nvim_get_current_buf()
    util.try(vim.api.nvim_win_close, self.winid, true)
    vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), current_bufnr)
  end

  if self.on_hide then
    self.on_hide()
  end
end

return Win
