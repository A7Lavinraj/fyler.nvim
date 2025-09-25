local M = {}

local did_setup = false

---@param opts FylerConfig
function M.setup(opts)
  if vim.fn.has "nvim-0.11" ~= 1 then
    return vim.notify "Fyler requires at least NVIM 0.11"
  end

  if did_setup then
    return
  end

  -- Overwrite default configuration before setuping other components
  local config = require "fyler.config"
  config.setup(opts)

  require("fyler.autocmds").setup(config)
  require("fyler.hooks").setup(config)
  require("fyler.lib.hls").setup()

  did_setup = true

  local explorer = require "fyler.explorer"
  local fs = require "fyler.lib.fs"
  local util = require "fyler.lib.util"

  M.open = vim.schedule_wrap(function(opts)
    opts = opts or {}
    local dir = opts.dir or fs.cwd()
    local kind = opts.kind or config.values.win.kind
    local instance = explorer.instance(dir)
    local current = explorer.current()
    if current and (current.dir ~= dir or current.win.kind ~= kind) then
      current:close()
    end

    if instance then
      instance:open(dir, kind)
    else
      explorer.new(dir, config):open(dir, kind)
    end
  end)

  ---@param name string|nil
  M.track_buffer = function(name)
    local current = explorer.current()
    if not current then
      return
    end

    util.debounce("focus_buffer", 10, function()
      current:track_buffer(name or vim.fn.expand "%:p")
    end)
  end
end

return M
