local M = {}

---@param path string|nil
---@return boolean
function M.is_protocol_path(path)
  return path and (not not path:match "^fyler://") or false
end

---@param str string
---@return integer|nil
function M.parse_ref_id(str)
  return tonumber(str:match "/(%d+)")
end

---@param str string
---@return integer
function M.parse_indent_level(str)
  return #(str:match("^(%s*)" or ""))
end

---@param str string
---@return string
function M.parse_name(str)
  if M.parse_ref_id(str) then
    return str:match "/%d+ (.*)$"
  else
    return str:gsub("^%s*", ""):match ".*"
  end
end

function M.fyler_auto_indent()
  local prevlnum = vim.v.lnum - 1
  local previndent = vim.fn.indent(prevlnum)
  return previndent
end

return M
