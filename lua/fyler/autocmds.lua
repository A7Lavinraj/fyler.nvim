local M = {}

local augroup = vim.api.nvim_create_augroup("fyler_augroup_global", { clear = true })

function M.setup(config)
  local fyler = require "fyler"
  local helper = require "fyler.views.finder.helper"
  local util = require "fyler.lib.util"

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
      desc = "Hijack directory buffers for fyler",
      callback = function(args)
        if util.get_buf_option(args.buf, "filetype") == "fyler" then
          return
        end
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if vim.fn.isdirectory(bufname) == 1 or helper.is_protocol_uri(bufname) then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              vim.api.nvim_buf_delete(args.buf, { force = true })
            end
            fyler.open { dir = helper.normalize_uri(bufname) }
          end)
        end
      end,
    })

    vim.api.nvim_create_autocmd({ "BufReadCmd", "SessionLoadPost" }, {
      group = augroup,
      pattern = "fyler://*",
      desc = "Open fyler protocol URIs",
      callback = function(args)
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if helper.is_protocol_uri(bufname) then
          local finder_instance = require("fyler.views.finder").instance(bufname)
          if not finder_instance:isopen() then
            vim.schedule(function()
              fyler.open { dir = bufname }
            end)
          end
        end
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
      callback = function(args)
        if not (helper.is_protocol_uri(args.file) or util.get_buf_option(args.buf, "filetype") == "fyler") then
          fyler.navigate(args.file)
        end
      end,
    })
  end
end

return M
