local util = require("fyler.lib.util")

---@class Path
---@field _original string
---@field _segments string[]|nil
local Path = {}
Path.__index = Path

---@return boolean
function Path.is_macos() return vim.uv.os_uname().sysname == "Darwin" end

---@return boolean
function Path.is_windows() return vim.uv.os_uname().sysname == "Windows_NT" end

---@return boolean
function Path.is_linux() return not (Path.is_macos() or Path.is_windows()) end

---@param path string
---@return Path
function Path.new(path)
  return setmetatable({
    _original = string.gsub(string.gsub(path, "^%s+", ""), "%s+$", ""),
    _segments = nil,
  }, Path)
end

---@return string[]
function Path:segments()
  if not self._segments then
    local abs = self:posix_path()
    local parts = vim.split(abs, "/", { plain = true })
    self._segments = util.filter_bl(parts)
  end
  return self._segments
end

---@return Path
function Path:parent() return Path.new(vim.fn.fnamemodify(vim.fs.normalize(self:posix_path()), ":h")) end

---@return string
function Path:basename()
  local segments = self:segments()
  return segments[#segments] or ""
end

---@return string
function Path:os_path()
  local path = self._original
  if Path.is_windows() then
    if vim.startswith(path, "/") then
      local drive = path:match("^/(%a+)")
      if drive then return string.format("%s:%s", drive, path:sub(drive:len() + 2):gsub("/", "\\")) end
    end
    return util.select_n(1, path:gsub("/", "\\"))
  else
    return util.select_n(1, path:gsub("\\", "/"))
  end
end

---@return string
function Path:posix_path()
  local path = self._original
  if Path.is_windows() then
    local drive, remaining = path:match("^([^:]+):\\(.*)$")
    if drive then return string.format("/%s/%s", drive:upper(), remaining:gsub("\\", "/")) end
    return util.select_n(1, path:gsub("\\", "/"))
  else
    return path
  end
end

---@return boolean
function Path:exists() return not not util.select_n(1, vim.uv.fs_stat(self:os_path())) end

---@return uv.fs_stat.result|nil
function Path:stats() return util.select_n(1, vim.uv.fs_stat(self:os_path())) end

---@return uv.fs_stat.result|nil
function Path:lstats() return util.select_n(1, vim.uv.fs_lstat(self:os_path())) end

---@return string|nil
function Path:type()
  local stat = self:lstats()
  if not stat then return end
  return stat.type
end

---@return boolean
function Path:is_link() return self:type() == "link" end

---@return boolean
function Path:is_file() return self:type() == "file" end

---@return boolean
function Path:is_directory()
  local t = self:type()
  if t then return t == "directory" end
  if Path.is_windows() then
    return vim.endswith(self._original, "\\")
  else
    return vim.endswith(self._original, "/")
  end
end

---@return boolean
function Path:is_absolute()
  if Path.is_windows() then
    -- Windows: check for drive letter or UNC path
    return self._original:match("^[A-Za-z]:") or self._original:match("^\\\\")
  else
    -- Unix: check for leading /
    return vim.startswith(self._original, "/")
  end
end

---@param ref string
---@return string|nil
function Path:relative(ref) return vim.fs.relpath(self:posix_path(), Path.new(ref):posix_path()) end

---@return Path
function Path:join(...) return Path.new(vim.fs.joinpath(self:posix_path(), ...)) end

---@param other string
---@return boolean
function Path:is_descendant_of(other)
  local other_path = Path.new(other)
  local self_segments = self:segments()
  local other_segments = other_path:segments()
  if #other_segments >= #self_segments then return false end
  for i = 1, #other_segments do
    if self_segments[i] ~= other_segments[i] then return false end
  end
  return true
end

---@param other string
---@return boolean
function Path:is_ancestor_of(other) return Path.new(other):is_descendant_of(self:posix_path()) end

---@return string|nil, string|nil
function Path:res_link()
  if not self:is_link() then return end

  local os_path = self:os_path()
  local current = Path.new(os_path)
  local visited = {}
  while current:is_link() do
    if visited[os_path] then return nil, "circular symlink" end
    visited[os_path] = true

    local read_link = vim.uv.fs_readlink(os_path)
    if not read_link then break end

    if not Path.new(read_link):is_absolute() then
      os_path = current:parent():join(read_link):os_path()
    else
      os_path = read_link
    end

    current = Path.new(os_path)
  end

  return os_path, (Path.new(os_path):lstats() or {}).type
end

---@return fun(): boolean|nil, string|nil
function Path:iter()
  local segments = self:segments()
  local i = 0
  return function()
    i = i + 1
    if i <= #segments then
      local path_parts = {}
      for j = 1, i do
        table.insert(path_parts, segments[j])
      end
      return i == #segments, table.concat({ "", util.unpack(path_parts) }, "/")
    end
  end
end

return Path
