local Path = require("fyler.lib.path")

local M = {}

function M.dump(opts, _next)
  local abspath = Path.new(opts.path):os_path()
  local Process = require("fyler.lib.process")
  local proc

  -- Built-in trash command available on macOS 15 and later
  proc = Process.new({
    path = "/usr/bin/trash",
    args = { abspath },
  })

  proc:spawn_async(function(code)
    vim.schedule(function()
      if code == 0 then
        pcall(_next)
      else
        pcall(_next, "failed to move to trash: " .. (proc:err() or ""))
      end
    end)
  end)
end

return M
