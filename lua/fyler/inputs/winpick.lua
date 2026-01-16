local Ui = require("fyler.lib.ui")
local Win = require("fyler.lib.win")
local util = require("fyler.lib.util")

local M = {}

---@param win_filter integer[]
---@param onsubmit fun(winid: integer|nil)
---@param opts FylerConfigWinpickBuiltinOpts|nil
function M.open(win_filter, onsubmit, opts)
  opts = opts or {}
  local chars = opts.chars or "asdfghjkl;"

  local winids = util.tbl_filter(vim.api.nvim_tabpage_list_wins(0), function(win)
    return not util.if_any(win_filter, function(c) return c == win end)
  end)
  assert(string.len(chars) >= #winids, "too many windows to select")

  if #winids <= 1 then return onsubmit(winids[1]) end

  local winid_to_win = {}
  local char_to_winid = {}
  for i, winid in ipairs(winids) do
    winid_to_win[winid] = Win.new({
      buf_opts = { modifiable = false },
      enter = false,
      height = 1,
      kind = "float",
      left = 0,
      top = 0,
      width = 3,
      win = winid,
    })
    winid_to_win[winid].render = function()
      winid_to_win[winid].ui:render({
        children = {
          Ui.Text(string.format(" %s ", string.sub(chars, i, i)), { highlight = "FylerWinPick" }),
        },
      }, function()
        if i == #winids then
          vim.cmd([[ redraw! ]])

          local winid = char_to_winid[vim.fn.getcharstr()]
          for _, win in pairs(winid_to_win) do
            win:hide()
          end

          onsubmit(winid)
        end
      end)
    end
    char_to_winid[string.sub(chars, i, i)] = winid
    winid_to_win[winid]:show()
  end
end

return M
