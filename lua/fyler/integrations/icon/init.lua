---@class IconIntegration
---@field mini_icon MiniIconsIntegration
---@field nvim_web_devicons NvimWebDeviconsIntegration
---@field vim_nerdfont VimNerdfontIntegration
local M = {}

setmetatable(M, {
  __index = function(_, k)
    if k == "none" then
      return function() end
    end

    local icon_provider = require("fyler.integrations.icon." .. k)

    return function(type, path) return icon_provider.get(type, path) end
  end,
})

return M
