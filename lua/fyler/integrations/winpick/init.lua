---@class WinpickIntegration
---@field none fun(win_filter: integer[], onsubmit: fun(winid: integer|nil), opts: table|nil)
---@field builtin fun(win_filter: integer[], onsubmit: fun(winid: integer|nil), opts: table|nil)
---@field nvim_window_picker fun(win_filter: integer[], onsubmit: fun(winid: integer|nil), opts: table|nil)
local M = {}

setmetatable(M, {
  __index = function(_, k)
    if k == "none" then
      return function(win_filter, onsubmit, _)
        local prev_winnr = vim.fn.winnr "#"
        local prev_winid = prev_winnr ~= 0 and vim.fn.win_getid(prev_winnr) or nil
        if prev_winid and vim.tbl_contains(win_filter, prev_winid) then
          prev_winid = nil
        end
        onsubmit(prev_winid)
      end
    end

    if k == "builtin" then
      return require("fyler.inputs.winpick").open
    end

    local ok, winpick_provider = pcall(require, "fyler.integrations.winpick." .. k:gsub("-", "_"))
    assert(ok, string.format("Winpick integration '%s' not found", k))

    return function(win_filter, onsubmit, opts)
      return winpick_provider.open(win_filter, onsubmit, opts)
    end
  end,
})

return M
