---@class FylerInputs
---@field confirm FylerInputsConfirm
local M = setmetatable({}, {
  __index = function(_, key)
    local ok, input = pcall(require, "fyler.inputs." .. key)
    assert(ok, string.format("Input '%s' not found", key))
    return input
  end,
})

return M
