vim.bo.readonly = true
vim.opt.statusline = " "
vim.opt.laststatus = 0
vim.opt.cmdheight = 0
vim.opt.fillchars = { eob = " " }

local mock_title = function(x)
  if type(x) ~= "string" then
    return x
  end
  local path = x:gsub("^.*/.temp/data", "MOCK_ROOT/data")
  return vim.fs.normalize(path)
end

_G.nvim_open_win_orig = vim.api.nvim_open_win

---@diagnostic disable-next-line
vim.api.nvim_open_win = function(buf_id, enter, config)
  config.title = mock_title(config.title)
  return nvim_open_win_orig(buf_id, enter, config)
end

_G.nvim_win_set_config_orig = vim.api.nvim_win_set_config

---@diagnostic disable-next-line
vim.api.nvim_win_set_config = function(win_id, config)
  config.title = mock_title(config.title)
  return nvim_win_set_config_orig(win_id, config)
end

local M = dofile "bin/setup_deps.lua"

---@param t table
---@return table
local function map(t)
  return vim
    .iter(t)
    :map(function(dep)
      return dep:match "/(.*)$"
    end)
    :totable()
end

for _, dep in ipairs(map(M.dependencies)) do
  local path = vim.fs.joinpath(M.get_dir(), "repo", dep)
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
  end
end

vim.opt.runtimepath:prepend "."
