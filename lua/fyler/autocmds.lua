local util = require("fyler.lib.util")

local M = {}

local api = vim.api
local fn = vim.fn

local augroup = api.nvim_create_augroup("Fyler", { clear = true })

function M.setup(config)
  config = config or {}

  if config.values.views.explorer.default_explorer then
    vim.cmd("silent! autocmd! FileExplorer *")
    vim.cmd("autocmd VimEnter * ++once silent! autocmd! FileExplorer *")

    api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      callback = function(arg)
        if vim.api.nvim_get_current_buf() ~= arg.buf then return end

        local path = vim.api.nvim_buf_get_name(0)
        if vim.fn.isdirectory(path) ~= 1 then return end

        util.set_buf_option(0, "bufhidden", "wipe")

        require("fyler").open { path = path }
      end,
    })
  end

  api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "FylerWinOpen",
    callback = function(arg)
      if not (arg.data.bufname and arg.data.bufname:match("fyler://*")) then return end

      api.nvim_win_call(arg.data.win, function()
        util.set_win_option(0, "concealcursor", "nvic")
        util.set_win_option(0, "conceallevel", 3)

        fn.matchadd("Conceal", [[/\d\d\d\d\d ]])
      end)
    end,
  })

  api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function() require("fyler.lib.hls").setup() end,
  })

  api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(arg)
      local cur_instance = require("fyler.views.explorer").get_current_instance()
      if cur_instance then cur_instance:_action("try_focus_buffer")(arg) end
    end,
  })
end

return M
