local M = {}

local did_setup = false

---@param opts FylerSetup
function M.setup(opts)
  if vim.fn.has "nvim-0.11" ~= 1 then
    return vim.notify "Fyler requires at least NVIM 0.11"
  end

  if did_setup then
    return
  end

  local util = require "fyler.lib.util"

  -- Overwrite default configuration before setuping other components
  for _, m in ipairs {
    { name = "fyler.config", args = { opts } },
    { name = "fyler.autocmds", args = { require "fyler.config" } },
    { name = "fyler.hooks", args = { require "fyler.config" } },
    { name = "fyler.lib.hl", args = {} },
  } do
    require(m.name).setup(util.unpack(m.args))
  end
  did_setup = true

  local finder = require "fyler.views.finder"

  M.close = finder.close

  M.open = vim.schedule_wrap(function(args)
    args = args or {}
    finder.open(args.dir, args.kind)
  end)

  M.toggle = function(args)
    args = args or {}
    finder.toggle(args.dir, args.kind)
  end

  ---@param name string|nil
  M.track_buffer = function(name)
    util.debounce("focus_buffer", 10, function()
      finder.track_buffer(name)
    end)
  end
end

return M
