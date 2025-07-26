local Ui = require("fyler.lib.ui")

local api = vim.api

---@alias FylerWinKind
---| "float"
---| "split:left"
---| "split:above"
---| "split:right"
---| "split:below"
---| "split:leftmost"
---| "split:abovemost"
---| "split:rightmost"
---| "split:belowmost"

---@class FylerWin
---@field augroup       string          - Autogroup associated with window instance
---@field autocmds      table           - Autocommands locally associated with window instance
---@field border        string|string[] - Border format - read ':winborder' for more info
---@field bufname       string          - Builtin way to name neovim buffers
---@field bufnr?        integer         - Buffer number associated with window instance
---@field buf_opts      table           - Buffer local options
---@field enter         boolean         - whether to enter in the window on open
---@field footer?       any             - Footer content
---@field footer_pos?   string          - Footer alignment
---@field height        number          - Height of window
---@field kind          FylerWinKind    - Decides launch behaviour of window instance
---@field mappings      table           - Kemaps local to the window instance
---@field name          string          - Also know as `view_name` which helps to get specific config from user end
---@field namespace     integer         - Namespace associated with window instance
---@field render?       function        - Defines what to render on the screen on open
---@field title?        any             - Title content
---@field title_pos?    string          - Title alignment
---@field ui            FylerUi         - Ui responsible to render lines return from corresponding render function
---@field user_autocmds table           - User autocommands associated with window instance
---@field width         number          - Width of window
---@field winid?        integer         - Window id associated with window instance
---@field win_opts      table           - Window local options
local Win = {}
Win.__index = Win

-- Prepares namespace ID by attaching buffer's given name
---@param name string
local function get_namespace(name)
  return api.nvim_create_namespace("Fyler" .. name)
end

-- Prepares autogroup ID by attaching buffer's given name
---@param name string
local function get_augroup(name)
  return api.nvim_create_augroup("Fyler" .. name, { clear = true })
end

local M = setmetatable({}, {
  ---@return FylerWin
  __call = function(_, opts)
    opts = opts or {}

    assert(opts.name, "name is required field")
    assert(opts.bufname, "bufname is required field")

    -- stylua: ignore start
    local instance = {
      augroup       = get_augroup(opts.name),
      autocmds      = opts.autocmds or {},
      border        = opts.border,
      bufname       = opts.bufname,
      buf_opts      = opts.buf_opts or {},
      enter         = opts.enter,
      footer        = opts.footer,
      footer_pos    = opts.footer_pos,
      height        = opts.height,
      kind          = opts.kind or "float",
      mappings      = opts.mappings or {},
      name          = opts.name or "",
      namespace     = get_namespace(opts.name),
      render        = opts.render,
      title         = opts.title,
      title_pos     = opts.title_pos,
      user_autocmds = opts.user_autocmds or {},
      width         = opts.width,
      win_opts      = opts.win_opts or {},
    }
    -- stylua: ignore end

    instance.ui = Ui(instance)
    setmetatable(instance, Win)

    return instance
  end,
})

-- Determine whether the `Win` has valid buffer
---@return boolean
function Win:has_valid_bufnr()
  return type(self.bufnr) == "number" and api.nvim_buf_is_valid(self.bufnr)
end

-- Determine whether the `Win` has valid window
---@return boolean
function Win:has_valid_winid()
  return type(self.winid) == "number" and api.nvim_win_is_valid(self.winid)
end

---@return boolean
function Win:is_visible()
  return self:has_valid_bufnr() and self:has_valid_winid()
end

-- Construct respective window config in vim understandable format
---@return vim.api.keyset.win_config
function Win:config()
  local winconfig = {
    style = "minimal",
    noautocmd = true,
    title = self.title,
    title_pos = self.title_pos,
    footer = self.footer,
    footer_pos = self.footer_pos,
  }

  if self.kind:match("^split:") then
    winconfig.split = self.kind:match("^split:(.*)")
    winconfig.title = nil
    winconfig.title_pos = nil
    winconfig.footer = nil
    winconfig.footer_pos = nil
  end

  if self.kind == "float" then
    winconfig.relative = "editor"
    winconfig.border = self.border
    winconfig.col = math.floor((1 - self.width) * 0.5 * vim.o.columns)
    winconfig.row = math.floor((1 - self.height) * 0.5 * vim.o.lines)
  end

  winconfig.width = (self.width <= 1.0) and math.ceil(self.width * vim.o.columns) or self.width
  winconfig.height = (self.height <= 1.0) and math.ceil(self.height * vim.o.lines) or self.height

  return winconfig
end

function Win:show()
  if self:has_valid_winid() then
    return
  end

  local recent_win = api.nvim_get_current_win()
  local win_config = self:config()

  self.bufnr = api.nvim_create_buf(false, true)
  if self.render then
    self.render()
  end

  api.nvim_buf_set_name(self.bufnr, self.bufname)

  if win_config.split and win_config.split:match("^%w+most$") then
    if win_config.split == "leftmost" then
      api.nvim_command(string.format("topleft %dvsplit", win_config.width))
    elseif win_config.split == "abovemost" then
      api.nvim_command(string.format("topleft %dsplit", win_config.height))
    elseif win_config.split == "rightmost" then
      api.nvim_command(string.format("botright %dvsplit", win_config.width))
    elseif win_config.split == "belowmost" then
      api.nvim_command(string.format("botright %dsplit", win_config.height))
    else
      error(string.format("Invalid window kind `%s`", win_config.split))
    end

    self.winid = api.nvim_get_current_win()

    if not self.enter then
      api.nvim_set_current_win(recent_win)
    end

    api.nvim_win_set_buf(self.winid, self.bufnr)
  else
    self.winid = api.nvim_open_win(self.bufnr, self.enter, win_config)
  end

  api.nvim_exec_autocmds("BufEnter", {})

  for mode, map in pairs(self.mappings) do
    for key, val in pairs(map) do
      vim.keymap.set(mode, key, val, { buffer = self.bufnr, silent = true, noremap = true })
    end
  end

  for option, value in pairs(self.win_opts) do
    vim.w[self.winid][option] = vim.wo[self.winid][option]
    vim.wo[self.winid][option] = value
  end

  for option, value in pairs(self.buf_opts) do
    vim.bo[self.bufnr][option] = value
  end

  for event, callback in pairs(self.autocmds) do
    api.nvim_create_autocmd(event, {
      group = self.augroup,
      buffer = self.bufnr,
      callback = callback,
    })
  end

  for event, callback in pairs(self.user_autocmds) do
    api.nvim_create_autocmd("User", {
      pattern = event,
      group = self.augroup,
      callback = callback,
    })
  end
end

function Win:hide()
  if self:has_valid_winid() then
    api.nvim_win_close(self.winid, true)
  end

  if self:has_valid_bufnr() then
    api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

return M
