local util = require "fyler.lib.util"

---@class Path
---@field _path string
---@field _sep string
local Path = {}
Path.__index = Path

---@return boolean
function Path.is_macos()
  return vim.uv.os_uname().sysname == "Darwin"
end

---@return boolean
function Path.is_linux()
  return not (Path.is_macos() or Path.is_windows())
end

---@return boolean
function Path.is_windows()
  return vim.uv.os_uname().version:match "Windows"
end

---@return boolean
function Path.is_path(t)
  return getmetatable(t) == Path
end

---@return string
function Path.root()
  return Path.is_windows() and "" or "/"
end

---@param segments string[]
---@return Path
function Path.from_segments(segments)
  local sep = Path.is_windows() and "\\" or "/"
  local root = Path.is_windows() and "" or "/"
  local path = root .. table.concat(segments, sep)
  return Path.new(path)
end

---@param path string
---@return Path
function Path.new(path)
  local instance = {
    _path = string.gsub(string.gsub(path, "^%s+", ""), "%s+$", ""),
    _sep = Path.is_windows() and "\\" or "/",
  }

  setmetatable(instance, Path)

  return instance
end

function Path:norm()
  return Path.new(string.gsub(self._path, self._sep .. "*$", ""))
end

---@return Path
function Path:parent()
  return Path.new(vim.fn.fnamemodify(self._path, ":h"))
end

---@return boolean
function Path:exists()
  return not not util.select_n(1, vim.uv.fs_stat(self._path))
end

---@return uv.fs_stat.result|nil
function Path:stats()
  return util.select_n(1, vim.uv.fs_stat(self._path))
end

---@return uv.fs_stat.result|nil
function Path:lstats()
  ---@diagnostic disable-next-line: param-type-mismatch
  return util.select_n(1, vim.uv.fs_lstat(self._path))
end

---@return string|nil
function Path:type()
  local stat = self:lstats()
  if not stat then
    return
  end

  return stat.type
end

---@return boolean
function Path:is_link()
  return self:type() == "link"
end

---@return boolean
function Path:is_dir()
  local t = self:type()
  if t then
    return t == "directory"
  end

  return vim.endswith(self:abspath(), self._sep)
end

---@return string
function Path:abspath()
  return vim.fs.abspath(self._path)
end

---@param ref string
---@return string|nil
function Path:relpath(ref)
  return vim.fs.relpath(self._path, ref)
end

---@return Path
function Path:joinpath(...)
  return Path.new(vim.fs.joinpath(self._path, ...))
end

---@return string|nil, string|nil
function Path:res_link()
  if not self:is_link() then
    return
  end

  local result = self:abspath()
  local current = Path.new(result)

  while current:is_link() do
    local read_link = vim.uv.fs_readlink(result)
    if type(read_link) ~= "string" then
      break
    end

    result, current = read_link, Path.new(read_link)
  end

  local stats = Path.new(result):lstats()
  return result, stats and stats.type or nil
end

---@return function
function Path:iter()
  local segments = vim.split(self:abspath(), self._sep)
  table.remove(segments, 1)

  local i = 0
  local target = Path.new ""
  return function()
    i = i + 1
    if i <= #segments then
      target = target:joinpath(segments[i])
      return i, target:abspath()
    end
  end
end

return Path
