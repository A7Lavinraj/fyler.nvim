local M = setmetatable({}, {
  __index = function(_, key)
    local Path = require("fyler.lib.path")
    if Path.is_windows() then
      return require("fyler.lib.trash.windows")[key]
    elseif Path.is_macos() then
      return require("fyler.lib.trash.macos")[key]
    else
      return require("fyler.lib.trash.linux")[key]
    end
  end,
})

return M
