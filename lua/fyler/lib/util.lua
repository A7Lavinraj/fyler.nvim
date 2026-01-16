local M = {}

---@param n integer
---@param ... any
function M.select_n(n, ...)
  local x = select(n, ...)
  return x
end

---@generic T
---@param tbl T[]
---@param start integer|nil
---@param stop integer|nil
---@return T ...
function M.unpack(tbl, start, stop)
  start = start or 1
  stop = stop or #tbl
  if start > stop then return end

  return tbl[start], M.unpack(tbl, start + 1, stop)
end

---@param tbl table
---@param fn function
function M.if_any(tbl, fn) return vim.iter(tbl):any(fn) end

---@param tbl table
---@param fn function
function M.if_all(tbl, fn) return vim.iter(tbl):all(fn) end

---@param value any
---@return table
function M.tbl_wrap(value) return type(value) == "table" and value or { value } end

---@param tbl table
---@param fn function
---@return any
function M.tbl_find(tbl, fn) return vim.iter(tbl):find(fn) end

---@param tbl table
---@param fn function
function M.tbl_map(tbl, fn) return vim.iter(tbl):map(fn):totable() end

---@param tbl table
---@param fn function
function M.tbl_each(tbl, fn) return vim.iter(tbl):each(fn) end

---@param tbl table
---@param fn function
function M.tbl_filter(tbl, fn) return vim.iter(tbl):filter(fn):totable() end

---@param a table
---@param b table
---@return table
function M.tbl_merge_force(a, b) return vim.tbl_deep_extend("force", a, b) end

---@param a table
---@param b table
---@return table
function M.tbl_merge_keep(a, b) return vim.tbl_deep_extend("keep", a, b) end

---@param tbl table
---@return table
function M.unique(tbl)
  local res = {}
  for i = 1, #tbl do
    if tbl[i] and not vim.tbl_contains(res, tbl[i]) then table.insert(res, tbl[i]) end
  end

  return res
end

---@param str string
---@return string
function M.camel_to_snake(str)
  if not str or str == "" then return str end

  local result = str:gsub("(%u)", function(c) return "_" .. c:lower() end)

  if result:sub(1, 1) == "_" then result = result:sub(2) end

  return result
end

---@param lines string[]
function M.filter_bl(lines)
  return vim.iter(lines):filter(function(line) return line ~= "" end):totable()
end

---@param winid number|nil
---@return boolean
function M.is_valid_winid(winid) return type(winid) == "number" and vim.api.nvim_win_is_valid(winid) end

---@param bufnr number|nil
---@return boolean
function M.is_valid_bufnr(bufnr) return type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) end

---@param winid integer
---@param option string
---@return any
function M.get_win_option(winid, option)
  if M.is_valid_winid(winid) then return vim.api.nvim_get_option_value(option, { win = winid, scope = "local" }) end
end

---@param bufnr integer
---@param option string
---@return any
function M.get_buf_option(bufnr, option)
  if M.is_valid_bufnr(bufnr) then return vim.api.nvim_get_option_value(option, { buf = bufnr, scope = "local" }) end
end

---@param winid integer
---@param option string
---@param value any
function M.set_win_option(winid, option, value)
  if M.is_valid_winid(winid) then vim.api.nvim_set_option_value(option, value, { win = winid, scope = "local" }) end
end

---@param bufnr integer
---@param option string
---@param value any
function M.set_buf_option(bufnr, option, value)
  if M.is_valid_bufnr(bufnr) then vim.api.nvim_set_option_value(option, value, { buf = bufnr, scope = "local" }) end
end

---@param str string
---@param max_length integer
---@param trailing string
function M.str_truncate(str, max_length, trailing)
  trailing = trailing or "..."
  if vim.fn.strdisplaywidth(str) > max_length then str = vim.trim(str:sub(1, max_length - #trailing)) .. trailing end
  return str
end

---@param fn function
---@param ... any
---@return boolean|any
function M.try(fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then return false end

  return result or true
end

---@type table<string, uv.uv_timer_t>
local running = {}

---@param name string
---@param timeout integer
---@param fn function
function M.debounce(name, timeout, fn)
  if running[name] then running[name]:stop() end

  running[name] = vim.defer_fn(function()
    running[name] = nil

    fn()
  end, timeout)
end

---@param index integer|nil
function M.cmd_history(index) return vim.fn.histget("cmd", index or -1) end

---@return string[]|nil
function M.get_visual_selection()
  local start_mark = vim.api.nvim_buf_get_mark(0, "<")
  local end_mark = vim.api.nvim_buf_get_mark(0, ">")
  local start_row, start_col = start_mark[1], start_mark[2]
  local end_row, end_col = end_mark[1], end_mark[2]
  if start_row == 0 or end_row == 0 then return nil end
  return vim.api.nvim_buf_get_text(0, start_row - 1, start_col, end_row - 1, end_col + 1, {})
end

return M
