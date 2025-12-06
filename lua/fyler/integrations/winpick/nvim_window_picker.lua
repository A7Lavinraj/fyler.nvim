---@class NvimWindowPickerIntegration
local M = {}

--- Note: win_filter is unused here because we filter by filetype instead,
--- which preserves the user's nvim-window-picker filter_rules configuration.
---@param _ integer[] Window IDs to filter (unused, filtered by filetype)
---@param onsubmit fun(winid: integer|nil)
---@param opts table<string, any>|nil Options passed to nvim-window-picker's pick_window()
function M.open(_, onsubmit, opts)
  local ok, window_picker = pcall(require, "window-picker")
  assert(ok, "nvim-window-picker is not installed or not loaded")

  opts = opts or {}

  -- Merge "fyler" into filter_rules.bo.filetype to exclude fyler windows
  local user_filetypes = opts.filter_rules and opts.filter_rules.bo and opts.filter_rules.bo.filetype or {}
  local filetypes = vim.list_extend({ "fyler" }, user_filetypes)

  local picker_opts = vim.tbl_deep_extend("force", opts, {
    filter_rules = {
      bo = {
        filetype = filetypes,
      },
    },
  })

  local winid = window_picker.pick_window(picker_opts)

  onsubmit(winid)
end

return M
