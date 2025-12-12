local Ui = require "fyler.lib.ui"
local Win = require "fyler.lib.win"
local util = require "fyler.lib.util"

local M = {}

local function create_winpick_entry(target_winid, char, is_last, char_to_winid, all_entries, onsubmit)
  local entry = {}

  entry.bufnr = vim.api.nvim_create_buf(false, true)
  entry.namespace = vim.api.nvim_create_namespace("fyler_winpick_" .. entry.bufnr)
  entry.ui = Ui.new(entry)

  entry.win = Win.new {
    bufnr = entry.bufnr,
    enter = false,
    height = 1,
    kind = "float",
    left = 0,
    top = 0,
    width = 3,
    win = target_winid,
  }

  function entry:set_lines(start, finish, lines)
    if not vim.api.nvim_buf_is_valid(self.bufnr) then
      return
    end
    local was_modifiable = util.get_buf_option(self.bufnr, "modifiable")
    util.set_buf_option(self.bufnr, "modifiable", true)
    vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace, 0, -1)
    vim.api.nvim_buf_set_lines(self.bufnr, start, finish, false, lines)
    if not was_modifiable then
      util.set_buf_option(self.bufnr, "modifiable", false)
    end
  end

  function entry:set_extmark(row, col, options)
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, row, col, options)
    end
  end

  function entry:hide()
    self.win:hide()
    util.try(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  end

  entry.win:show()

  util.set_buf_option(entry.bufnr, "modifiable", false)

  entry.ui:render({
    children = {
      Ui.Text(string.format(" %s ", char), { highlight = "FylerWinPick" }),
    },
  }, function()
    if is_last then
      vim.cmd [[ redraw! ]]

      local selected_winid = char_to_winid[vim.fn.getcharstr()]
      for _, e in pairs(all_entries) do
        e:hide()
      end

      onsubmit(selected_winid)
    end
  end)

  return entry
end

---@param win_filter integer[]
---@param onsubmit fun(winid: integer|nil)
---@param opts FylerConfigWinpickBuiltinOpts|nil
function M.open(win_filter, onsubmit, opts)
  opts = opts or {}
  local chars = opts.chars or "asdfghjkl;"

  local winids = util.tbl_filter(vim.api.nvim_tabpage_list_wins(0), function(win)
    return not util.if_any(win_filter, function(c)
      return c == win
    end)
  end)
  assert(string.len(chars) >= #winids, "too many windows to select")

  if #winids <= 1 then
    return onsubmit(winids[1])
  end

  local winid_to_entry = {}
  local char_to_winid = {}

  for i, winid in ipairs(winids) do
    char_to_winid[string.sub(chars, i, i)] = winid
  end

  for i, winid in ipairs(winids) do
    local char = string.sub(chars, i, i)
    local is_last = (i == #winids)
    winid_to_entry[winid] = create_winpick_entry(winid, char, is_last, char_to_winid, winid_to_entry, onsubmit)
  end
end

return M
