local M = {}
local api = vim.api

local augroup = api.nvim_create_augroup("Fyler-augroup-global", { clear = true })

function M.setup(config)
  config = config or {}

  if config.values.default_explorer then
    vim.cmd "silent! autocmd! FileExplorer *"
    vim.cmd "autocmd VimEnter * ++once silent! autocmd! FileExplorer *"

    api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      desc = "Hijack NETRW commands",
      callback = function(arg)
        if api.nvim_get_current_buf() ~= arg.buf then
          return
        end

        local path = api.nvim_buf_get_name(0)
        if vim.fn.isdirectory(path) ~= 1 then
          return
        end

        api.nvim_buf_delete(0, { force = true })
        require("fyler").open { dir = path }
      end,
    })
  end

  api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    desc = "Adjust highlight groups with respect to colorscheme",
    callback = function()
      require("fyler.lib.hls").setup()
    end,
  })

  if config.values.track_current_buffer then
    api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      desc = "Track current focused buffer in explorer",
      callback = function(arg)
        require("fyler").track_buffer(arg.file)
      end,
    })
  end

  api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    desc = "Drop explorer window when buffer inside it changes to NON FYLER BUFFER",
    callback = function(arg)
      local instance = require("fyler.explorer").current()
      if not instance then
        return
      end

      if not instance.win:has_valid_winid() then
        return
      end

      local bufnr = arg.buf
      local bufname = api.nvim_buf_get_name(bufnr)
      if require("fyler.explorer.util").is_protocol_path(bufname) then
        return
      end

      if api.nvim_win_get_buf(instance.win.winid) == bufnr then
        instance.win:recover()
      end
    end,
  })

  api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = { "Fyler" },
    callback = function()
      vim.opt_local.indentexpr = "v:lua.require('fyler.explorer.util').fyler_auto_indent()"
    end,
  })
end

return M
