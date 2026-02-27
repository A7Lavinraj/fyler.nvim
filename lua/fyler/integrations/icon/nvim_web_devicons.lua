---@class NvimWebDeviconsIntegration
local M = {}

function M.get(type, path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  assert(ok, "nvim-web-devicons are not installed or not loaded")

  local icon, hl = devicons.get_icon(vim.fn.fnamemodify(path, ":t"))
  icon = (type == "directory" and "" or (icon or ""))
  hl = hl or (type == "directory" and "Fylerblue" or "")

  return icon, hl
end

return M
