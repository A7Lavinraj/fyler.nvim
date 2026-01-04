local M = {}

---@param uri string|nil
---@return boolean
function M.is_protocol_uri(uri)
  return uri and (not not uri:match "^fyler://") or false
end

---@param dir string
---@param tab string|integer
---@return string
function M.build_protocol_uri(dir, tab)
  return string.format("fyler://%s?tab=%s", dir, tostring(tab))
end

---@param uri string|nil
---@return string
function M.normalize_uri(uri)
  local fs = require "fyler.lib.fs"
  local dir, tab = nil, nil
  if not uri or uri == "" then
    dir = fs.cwd()
    tab = tostring(vim.api.nvim_get_current_tabpage())
  elseif M.is_protocol_uri(uri) then
    dir, tab = M.parse_protocol_uri(uri)
    dir = dir or fs.cwd()
    tab = tab or tostring(vim.api.nvim_get_current_tabpage())
  else
    dir = uri
    tab = tostring(vim.api.nvim_get_current_tabpage())
  end

  return M.build_protocol_uri(require("fyler.lib.path").new(dir):normalize(), tab)
end

---@param uri string
---@return string|nil, string|nil
function M.parse_protocol_uri(uri)
  if M.is_protocol_uri(uri) then
    local path_with_query = uri:gsub("fyler://", "")
    local path, tab = path_with_query:match "^(.*)%?tab=(.*)"
    return path or path_with_query, tab
  end
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

return M
