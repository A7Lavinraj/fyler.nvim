local M = {}

local augroup = vim.api.nvim_create_augroup("fyler_augroup_global", { clear = true })

function M.setup(config)
  local fyler = require "fyler"

  config = config or {}

  if config.values.views.finder.default_explorer then
    -- Disable NETRW plugin
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    -- Clear NETRW auto commands if NETRW loaded before disable
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

  if config.values.views.finder.follow_current_file then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      desc = "Track current focused buffer in finder",
      callback = function(arg)
        if not (require("fyler.lib.util").is_protocol_uri(arg.file) or arg.file == "") then
          fyler.navigate(arg.file)
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd({ "BufReadCmd", "SessionLoadPost" }, {
    group = augroup,
    pattern = "fyler://*",
    desc = "Load with URI",
    nested = true,
    callback = function(arg)
      fyler.open { dir = arg.file }
    end,
  })
end

return M
