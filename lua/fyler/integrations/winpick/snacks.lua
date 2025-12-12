---@class SnacksWinpickIntegration
local M = {}

--- Note: win_filter is unused here because snacks.picker.util.pick_win
--- filters by filetype instead.
---@param _ integer[] Window IDs to filter (unused, filtered by filetype)
---@param onsubmit fun(winid: integer|nil)
---@param opts table<string, any>|nil Options passed to snacks.picker.util.pick_win()
function M.open(_, onsubmit, opts)
  local ok, snacks_picker_util = pcall(require, "snacks.picker.util")
  assert(ok, "snacks.nvim picker is not installed or not loaded")

  opts = opts or {}

  -- Merge filter to exclude fyler windows
  local user_filter = opts.filter
  local picker_opts = vim.tbl_deep_extend("force", opts, {
    filter = function(win, buf)
      if vim.bo[buf].filetype == "fyler" then
        return false
      end
      if user_filter then
        return user_filter(win, buf)
      end
      return true
    end,
  })

  local winid = snacks_picker_util.pick_win(picker_opts)

  onsubmit(winid)
end

return M
