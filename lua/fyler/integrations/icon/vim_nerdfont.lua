---@class VimNerdfontIntegration
local M = {}

function M.get(type, path)
  assert(vim.fn.exists("*nerdfont#find"), "vim-nerdfont are not installed or not loaded")

  if type == "directory" then
    return vim.fn["nerdfont#directory#find"]()
  else
    return vim.fn["nerdfont#find"](path)
  end
end

return M
