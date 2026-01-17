-- Immediately add plugins to runtimepath
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.getcwd(), ".temp", "deps", "mini.icons"))
vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.getcwd(), ".temp", "deps", "mini.test"))

-- Clear all highlights(better for screenshots)
vim.cmd("hi! clear")

-- stylua: ignore
for o, v in pairs({
  background  = "dark",
  backup      = false,
  cmdheight   = 0,
  fillchars   = { eob = " " },
  laststatus  = 0,
  readonly    = true,
  statusline  = " ",
  swapfile    = false,
  tabline     = " ",
  writebackup = false,
}) do vim.opt[o] = v end

local mock_title = function(x)
  if type(x) ~= "string" then return x end
  return x:gsub("^.*/.temp/data", "MOCK_ROOT/data")
end

_G.nvim_open_win_orig = vim.api.nvim_open_win

vim.api.nvim_open_win = function(buf_id, enter, config)
  config.title = mock_title(config.title)
  return nvim_open_win_orig(buf_id, enter, config)
end

_G.nvim_win_set_config_orig = vim.api.nvim_win_set_config

vim.api.nvim_win_set_config = function(win_id, config)
  config.title = mock_title(config.title)
  return nvim_win_set_config_orig(win_id, config)
end

_G.FYLER_TEMP_DIR = vim.fs.joinpath(vim.uv.cwd(), ".temp")
