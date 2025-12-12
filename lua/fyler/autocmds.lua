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
      -- Scheduling to let Finder.files update completely
      callback = vim.schedule_wrap(function(arg)
        fyler.navigate(arg.file)
      end),
    })
  end

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    desc = "Drop finder window when buffer inside it changes to NON FYLER BUFFER",
    callback = function()
      require("fyler.views.finder").recover()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufReadCmd", "SessionLoadPost" }, {
    group = augroup,
    pattern = "fyler://*",
    desc = "Load on fyler://",
    nested = true,
    callback = function(arg)
      require("fyler.views.finder").load(arg.file)
    end,
  })

  -- Cleanup invalid windows when tabs are closed
  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup,
    desc = "Clean up invalid fyler windows when tabs close",
    callback = function()
      local finder_module = require "fyler.views.finder"
      for _, finder in pairs(finder_module._finders) do
        finder:cleanup_invalid_windows()
      end
    end,
  })
end

return M
