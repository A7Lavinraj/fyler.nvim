local config = require("fyler.config")

local M = {}

local INDENT_WIDTH = 2
local snapshots = {}

---@param winid integer
---@param bufnr integer
---@return string
local function make_key(winid, bufnr) return winid .. "_" .. bufnr end

---@param text string
---@return boolean
local function only_spaces_or_tabs(text)
  for i = 1, #text do
    local byte = string.byte(text, i)
    if byte ~= 32 and byte ~= 9 then return false end
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
---@param snapshot table
---@return integer indent
local function compute_indent(bufnr, lnum, snapshot)
  local cached = snapshot[lnum]
  if cached then return cached end

  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, lnum - 1, lnum, false)
  if not ok or not lines or #lines == 0 then return 0 end

  local line = lines[1]
  local is_empty = #line == 0 or only_spaces_or_tabs(line)

  local indent
  if is_empty then
    indent = 0
    local prev_lnum = lnum - 1
    while prev_lnum >= 1 do
      local prev_indent = snapshot[prev_lnum] or compute_indent(bufnr, prev_lnum, snapshot)
      if prev_indent > 0 then
        indent = prev_indent
        break
      end
      prev_lnum = prev_lnum - 1
    end
  else
    indent = calculate_indent(line)
  end

  snapshot[lnum] = indent
  return indent
end

---@param snapshot table
---@param lnum integer
---@return integer|nil
local function next_non_empty_indent(snapshot, lnum)
  local next_lnum = lnum + 1
  while true do
    local next_indent = snapshot[next_lnum]
    if next_indent == nil then return nil end
    if next_indent > 0 then return next_indent end
    next_lnum = next_lnum + 1
  end
end

local function setup_provider()
  if M.indent_ns then return end

  M.indent_ns = vim.api.nvim_create_namespace("fyler_indentscope")

  vim.api.nvim_set_decoration_provider(M.indent_ns, {
    on_start = function()
      if not config.values.views.finder.indentscope.enabled then return false end

      for key in pairs(M.windows) do
        snapshots[key] = {}
      end
      return true
    end,

    on_win = function(_, winid, bufnr, topline, botline)
      local key = make_key(winid, bufnr)
      local win = M.windows[key]
      if not win or not win:has_valid_bufnr() or win.winid ~= winid or win.bufnr ~= bufnr then return false end

      local snapshot = snapshots[key] or {}
      snapshots[key] = snapshot

      for lnum = topline + 1, botline + 1 do
        compute_indent(bufnr, lnum, snapshot)
      end

      return true
    end,

    on_line = function(_, winid, bufnr, row)
      local key = make_key(winid, bufnr)
      local win = M.windows[key]
      if not win or not win:has_valid_bufnr() or win.winid ~= winid or win.bufnr ~= bufnr then return end

      local snapshot = snapshots[key]
      if not snapshot then return end

      local lnum = row + 1
      local indent = snapshot[lnum]
      if not indent or indent < INDENT_WIDTH then return end

      local next_indent = next_non_empty_indent(snapshot, lnum)
      local markers = config.values.views.finder.indentscope.markers

      for col = 0, indent - INDENT_WIDTH, INDENT_WIDTH do
        local scope_level = col + INDENT_WIDTH
        local is_scope_end = not next_indent or next_indent < scope_level

        local marker = is_scope_end and markers[2] or markers[1]

        vim.api.nvim_buf_set_extmark(bufnr, M.indent_ns, row, col, {
          virt_text = { marker },
          virt_text_pos = "overlay",
          hl_mode = "combine",
          ephemeral = true,
          priority = 10,
        })
      end
    end,
  })
end

---@param win Win
function M.attach(win)
  if not config.values.views.finder.indentscope.enabled then return end

  setup_provider()

  if not M.windows then M.windows = {} end

  local key = make_key(win.winid, win.bufnr)
  M.windows[key] = win
end

---@param win Win
function M.detach(win)
  if not M.windows then return end

  local key = make_key(win.winid, win.bufnr)
  M.windows[key] = nil
  snapshots[key] = nil

  if next(M.windows) == nil then
    M.windows = {}
    snapshots = {}
  end
end

function M.enable(win) M.attach(win) end

function M.disable()
  M.windows = {}
  snapshots = {}
end

return M
