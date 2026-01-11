local M = {}

local augroup = vim.api.nvim_create_augroup("fyler_augroup_global", { clear = true })

function M.setup(config)
  local fyler = require("fyler")
  local helper = require("fyler.views.finder.helper")
  local util = require("fyler.lib.util")
  local Path = require("fyler.lib.path")

  config = config or {}

  if config.values.views.finder.default_explorer then
    -- Disable NETRW plugin
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    -- Clear NETRW auto commands if NETRW loaded before disable
    vim.cmd("silent! autocmd! FileExplorer *")
    vim.cmd("autocmd VimEnter * ++once silent! autocmd! FileExplorer *")

    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      desc = "Hijack directory buffers for fyler",
      callback = function(args)
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if Path.new(bufname):is_directory() or helper.is_protocol_uri(bufname) then
          vim.schedule(function()
            if util.get_buf_option(args.buf, "filetype") == "fyler" then return end

            if vim.api.nvim_buf_is_valid(args.buf) then vim.api.nvim_buf_delete(args.buf, { force = true }) end

            fyler.open({ dir = helper.normalize_uri(bufname) })
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
          if not finder_instance:isopen() then vim.schedule(function() fyler.open({ dir = bufname }) end) end
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    desc = "Adjust highlight groups with respect to colorscheme",
    callback = function() require("fyler.lib.hl").setup() end,
  })

  if config.values.views.finder.follow_current_file then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      desc = "Track current focused buffer in finder",
      callback = function(arg)
        if helper.is_protocol_uri(arg.file) or arg.file == "" then return end

        vim.schedule(function()
          if not util.get_buf_option(arg.buf, "filetype") == "fyler" then fyler.navigate(arg.file) end
        end)
      end,
    })
  end
end

return M
