local M = {}

local did_setup = false

local api = vim.api

---@param opts FylerConfig
function M.setup(opts)
  if did_setup then
    return
  end

  local config = require("fyler.config")
  local autocmds = require("fyler.autocmds")
  local colors = require("fyler.lib.hls")

  M.augroup = vim.api.nvim_create_augroup("Fyler", { clear = true })
  M.config = config
  M.colors = colors
  M.aucmds = autocmds

  M.config.setup(opts)
  M.colors.setup()
  M.aucmds.setup()

  if config.values.default_explorer then
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    if vim.fn.exists("#FileExplorer") then
      api.nvim_create_augroup("FileExplorer", { clear = true })
    end

    if vim.v.vim_did_enter == 0 then
      local arg_path = vim.fn.argv(0)
      local first_arg = type(arg_path) == "string" and arg_path or arg_path[1]
      if vim.fn.isdirectory(first_arg) == 0 then
        return
      end

      local current_bufnr = api.nvim_get_current_buf()
      if api.nvim_buf_is_valid(current_bufnr) then
        api.nvim_buf_delete(current_bufnr, { force = true })
      end

      vim.schedule(function()
        M.open { cwd = arg_path }
      end)
    end
  end

  did_setup = true
end

function M.open(opts)
  opts = opts or {}

  require("fyler.views.explorer").open {
    cwd = opts.cwd,
    kind = opts.kind,
    config = M.config,
  }
end

function M.complete(arglead, cmdline)
  if arglead:find("^kind=") then
    return {
      "kind=split:left",
      "kind=split:above",
      "kind=split:right",
      "kind=split:below",
    }
  end

  if arglead:find("^cwd=") then
    return {
      "cwd=" .. (vim.uv or vim.loop).cwd(),
    }
  end

  return vim.tbl_filter(function(arg)
    return cmdline:match(arg) == nil
  end, {
    "kind=",
    "cwd=",
  })
end

return M
