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
---@field buf_opts table
---@field bufname string
---@field bufnr integer|nil
---@field enter boolean
---@field footer string|string[]|nil
---@field footer_pos string|nil
---@field height string
---@field kind WinKind
---@field left integer|string|nil
---@field mappings table
---@field mappings_opts vim.keymap.set.Opts
---@field namespace integer
---@field on_hide function|nil
---@field on_show function|nil
---@field render function|nil
---@field right integer|string|nil
---@field title string|string[]|nil
---@field title_pos string|nil
---@field top integer|string|nil
---@field ui Ui
---@field user_autocmds table
---@field user_mappings table
---@field width integer|string
---@field win integer|nil
---@field win_opts table
---@field winid integer|nil
local Win = {}
Win.__index = Win

---@return Win
function Win.new(opts)
  local instance = util.tbl_merge_keep(opts or {}, { kind = "replace" })
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

function Win:set_local_buf_option(k, v)
  if self:has_valid_bufnr() then
    util.set_buf_option(self.bufnr, k, v)
  end
end

function Win:set_local_win_option(k, v)
  if self:has_valid_winid() then
    util.set_win_option(self.winid, k, v)
  end
end

function Win:get_local_buf_option(k)
  if self:has_valid_bufnr() then
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

---@param start integer
---@param finish integer
---@param lines string[]
function Win:set_lines(start, finish, lines)
  if not self:has_valid_bufnr() then
    return
  end

  local was_modifiable = util.get_buf_option(self.bufnr, "modifiable")
  local undolevels = util.get_buf_option(self.bufnr, "undolevels")

  self:set_local_buf_option("modifiable", true)
  self:set_local_buf_option("undolevels", -1)

  vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace, 0, -1)
  vim.api.nvim_buf_set_lines(self.bufnr, start, finish, false, lines)

  if not was_modifiable then
    self:set_local_buf_option("modifiable", false)
  end

  self:set_local_buf_option("modified", false)
  self:set_local_buf_option("undolevels", undolevels)
end

---@param row integer
---@param col integer
---@param options vim.api.keyset.set_extmark
function Win:set_extmark(row, col, options)
  if self:has_valid_bufnr() then
    vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, row, col, options)
  end
end

function Win:focus()
  local windows = vim.fn.win_findbuf(self.bufnr)
  if not windows or not windows[1] then
    return
  end

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
  local win_config = self:config()
  local current_bufnr = vim.api.nvim_get_current_buf()
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

    if self.bufname then
      self.bufnr = vim.fn.bufnr(self.bufname)
    end

    if not self.bufnr or self.bufnr == -1 then
      self.bufnr = vim.api.nvim_create_buf(false, true)

      if self.bufname then
        vim.api.nvim_buf_set_name(self.bufnr, self.bufname)
      end
    end

    vim.api.nvim_win_set_buf(self.winid, self.bufnr)

    if not self.enter then
      vim.api.nvim_set_current_win(current_bufnr)
    end
  elseif self.kind:match "^replace" then
    self.winid = vim.api.nvim_get_current_win()

    if self.bufname then
      self.bufnr = vim.fn.bufnr(self.bufname)
    end

    if not self.bufnr or self.bufnr == -1 then
      vim.api.nvim_command "enew"
      self.bufnr = vim.api.nvim_get_current_buf()

      if self.bufname then
        vim.api.nvim_buf_set_name(self.bufnr, self.bufname)
      end
    else
      vim.api.nvim_win_set_buf(self.winid, self.bufnr)
    end
  else
    if self.bufname then
      self.bufnr = vim.fn.bufnr(self.bufname)
    end

    if not self.bufnr or self.bufnr == -1 then
      self.bufnr = vim.api.nvim_create_buf(false, true)

      if self.bufname then
        vim.api.nvim_buf_set_name(self.bufnr, self.bufname)
      end
    end

    self.winid = vim.api.nvim_open_win(self.bufnr, self.enter, win_config)
  end

  if self.on_show then
    self.on_show()
  end

  self.augroup = vim.api.nvim_create_augroup("fyler_augroup_win_" .. self.bufnr, { clear = true })
  self.namespace = vim.api.nvim_create_namespace("fyler_namespace_win_" .. self.bufnr)

  local mappings_opts = self.mappings_opts or {}
  mappings_opts.buffer = self.bufnr
  for keys, v in pairs(self.mappings or {}) do
    for _, k in ipairs(util.tbl_wrap(keys)) do
      vim.keymap.set("n", k, v, mappings_opts)
    end
  end

  for k, v in pairs(self.user_mappings or {}) do
    vim.keymap.set("n", k, v, mappings_opts)
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

  vim.api.nvim_buf_attach(self.bufnr, false, {
    on_detach = function()
      if self.autocmds or self.user_autocmds then
        pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
      end
    end,
  })

  if self.render then
    self.render()
  end
end

function Win:hide()
  if self.kind:match "^replace" then
    local altbufnr = vim.fn.bufnr "#"
    if altbufnr == -1 or altbufnr == self.bufnr then
      util.try(vim.cmd.enew)
    else
      util.try(vim.api.nvim_win_set_buf, self.winid, altbufnr)
    end
  else
    util.try(vim.api.nvim_win_close, self.winid, true)
  end

  util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })

  if self.on_hide then
    self.on_hide()
  end
end

return Win
