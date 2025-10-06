local M = {}

local augroup = vim.api.nvim_create_augroup("Fyler-augroup-global", { clear = true })

function M.setup(config)
  local fyler = require "fyler"

  config = config or {}

  if config.values.views.finder.default_explorer then
    vim.cmd "silent! autocmd! FileExplorer *"
    vim.cmd "autocmd VimEnter * ++once silent! autocmd! FileExplorer *"

    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      desc = "Hijack NETRW commands",
      callback = function(arg)
        if vim.api.nvim_get_current_buf() ~= arg.buf then
          return
        end

        local path = vim.api.nvim_buf_get_name(0)
        if vim.fn.isdirectory(path) ~= 1 then
          return
        end

        vim.api.nvim_buf_delete(0, { force = true })
        fyler.open { dir = path }
      end,
    })
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    desc = "Adjust highlight groups with respect to colorscheme",
    callback = function()
      require("fyler.lib.hl").setup()
    end,
  })

  if config.values.views.finder.track_current_buffer then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      desc = "Track current focused buffer in finder",
      callback = function(arg)
        fyler.track_buffer(arg.file)
      end,
    })
  end

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    desc = "Drop finder window when buffer inside it changes to NON FYLER BUFFER",
    callback = function()
      require("fyler.views.finder").recover()
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = { "Fyler" },
    callback = function()
      vim.opt_local.indentexpr = "v:lua.require('fyler.explorer.util').fyler_auto_indent()"
    end,
  })
end

return M
