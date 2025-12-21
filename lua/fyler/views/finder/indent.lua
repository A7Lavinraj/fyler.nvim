local config = require "fyler.config"

local M = {
  wins = {},
}

local INDENT_WIDTH = 2
local snapshot = {}

---@param text string
---@return boolean
local function only_spaces_or_tabs(text)
  for i = 1, #text do
    local byte = string.byte(text, i)
    if byte ~= 32 and byte ~= 9 then
      return false
    end
  end
  return true
end

---@param line string
---@return integer
local function calculate_indent(line)
  local indent = 0
  for i = 1, #line do
    local byte = string.byte(line, i)
    if byte == 32 then
      indent = indent + 1
    elseif byte == 9 then
      indent = indent + 8
    else
      break
    end
  end
  return indent
end

---@param bufnr integer
---@param lnum integer
---@return integer indent
local function compute_indent(bufnr, lnum)
  if not snapshot[bufnr] then
    snapshot[bufnr] = {}
  end

  local cached = snapshot[bufnr][lnum]
  if cached then
    return cached
  end

  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, lnum - 1, lnum, false)
  if not ok or not lines or #lines == 0 then
    return 0
  end

  local line = lines[1]
  local is_empty = #line == 0 or only_spaces_or_tabs(line)

  local indent
  if is_empty then
    indent = 0
    local prev_lnum = lnum - 1
    while prev_lnum >= 1 do
      local prev_indent = snapshot[bufnr][prev_lnum] or compute_indent(bufnr, prev_lnum)
      if prev_indent > 0 then
        indent = prev_indent
        break
      end
      prev_lnum = prev_lnum - 1
    end
  else
    indent = calculate_indent(line)
  end

  snapshot[bufnr][lnum] = indent

  return indent
end

local function setup_provider()
  if M.indent_ns then
    return
  end

  M.indent_ns = vim.api.nvim_create_namespace "fyler_indentscope"

  vim.api.nvim_set_decoration_provider(M.indent_ns, {
    on_start = function()
      if not M.enabled or not config.values.views.finder.indentscope.enabled then
        return false
      end

      snapshot = {}
      return true
    end,

    on_win = function(_, winid, bufnr, topline, botline)
      if not M.enabled then
        return false
      end

      local found_win
      for win, _ in pairs(M.wins) do
        if win:has_valid_winid() and win.winid == winid and win.bufnr == bufnr then
          found_win = win
          break
        end
      end

      if not found_win then
        return false
      end

      for lnum = topline + 1, botline + 1 do
        compute_indent(bufnr, lnum)
      end

      return true
    end,

    on_line = function(_, _, bufnr, row)
      if not M.enabled then
        return
      end

      local lnum = row + 1
      local indent = snapshot[bufnr] and snapshot[bufnr][lnum]

      if indent and indent >= INDENT_WIDTH then
        for col = 0, indent - INDENT_WIDTH, INDENT_WIDTH do
          vim.api.nvim_buf_set_extmark(bufnr, M.indent_ns, row, col, {
            virt_text = {
              { config.values.views.finder.indentscope.marker, config.values.views.finder.indentscope.group },
            },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            ephemeral = true,
            priority = 10,
          })
        end
      end
    end,
  })
end

---@param win Win
function M.enable(win)
  if not config.values.views.finder.indentscope.enabled then
    return
  end

  setup_provider()

  M.wins[win] = true
  M.enabled = true
end

---@param win Win|nil
function M.disable(win)
  if win then
    M.wins[win] = nil
    if vim.tbl_isempty(M.wins) then
      M.enabled = false
      snapshot = {}
    end
  else
    M.wins = {}
    M.enabled = false
    snapshot = {}
  end
end

return M
