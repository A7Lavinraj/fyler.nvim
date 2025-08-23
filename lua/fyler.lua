local M = {}

-- A local variable which prevents "Fyler.nvim" to re-setup
local did_setup = false

-- Setup function setup various plugin components, Like config, autocommands, hooks and highlights.
-- It also exposes some "Fyler.nvim" APIS
---@param options FylerConfig
function M.setup(options)
  if vim.fn.has("nvim-0.11") ~= 1 then return vim.notify("Fyler requires at least NVIM 0.11") end

  -- Early return if already been setuped
  if did_setup then return end
  -- Overwrite default configuration before setuping other components
  local config = require("fyler.config")
  config.setup(options)

  require("fyler.autocmds").setup(config)
  require("fyler.hooks").setup(config)
  require("fyler.lib.hls").setup()

  -- Mark setup as completed
  did_setup = true

  local util = require("fyler.lib.util")
  local fs = require("fyler.lib.fs")
  -- local explorer = require("fyler.views.explorer")
  -- local log = require("fyler.log")
  local manager = require("fyler.manager").get_manager()

  -- "Fyler.nvim" API to launch explorer with defined options
  M.open = vim.schedule_wrap(
    function(opts)
      manager:open(util.tbl_merge_keep(opts or {}, {
        cwd = fs.getcwd(),
        enter = true,
        kind = config.get_view_config("explorer").win.kind,
      }))
    end
  )

  -- "Fyler.nvim" API to track (given or current) buffer
  ---@param file string|nil
  M.track_buffer = function(file) manager:track_buffer(file) end
end

return M
