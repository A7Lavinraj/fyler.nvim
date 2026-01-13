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
  writebackup = false,
}) do vim.opt[o] = v end

_G.FYLER_TEMP_DIR = vim.fs.joinpath(vim.uv.cwd(), ".temp")
