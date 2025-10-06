local Path = require "fyler.lib.path"
local util = require "fyler.lib.util"

local c = {}

function c.cwd()
  return vim.uv.cwd()
end

---@param path string
function c.ls(path)
  local _path = Path.new(path)
  if not (_path:exists() and _path:is_dir()) then
    return
  end

  local contents = {}
  ---@diagnostic disable-next-line: param-type-mismatch
  local dir = vim.uv.fs_opendir(_path:abspath(), nil, 100)
  if not dir then
    return
  end

  local entries = vim.uv.fs_readdir(dir)
  while entries do
    vim.list_extend(
      contents,
      util.tbl_map(entries, function(e)
        local f = _path:joinpath(e.name)
        local p, t = f:res_link()
        return {
          name = e.name,
          path = p or f:abspath(),
          type = e.type == "link" and t or e.type,
          link = f:abspath(),
        }
      end)
    )

    entries = vim.uv.fs_readdir(dir)
  end

  return contents
end

function c.touch(path)
  assert(path, "path is not provided")

  local _path = Path.new(path)

  local fd = assert(vim.uv.fs_open(_path:abspath(), "a", 420))
  assert(vim.uv.fs_close(fd))
end

function c.mkdir(path, flags)
  assert(path, "path is not provided")

  local _path = Path.new(path)
  flags = flags or {}

  if flags.p then
    for _, prefix in _path:iter() do
      pcall(c.mkdir, prefix)
    end
  else
    assert(vim.uv.fs_mkdir(_path:abspath(), 493))
  end
end

local function _read_dir_iter(path)
  ---@diagnostic disable-next-line: param-type-mismatch
  local dir = vim.uv.fs_opendir(path, nil, 1000)
  if not dir then
    return function() end
  end

  local entries = vim.uv.fs_readdir(dir)
  vim.uv.fs_closedir(dir)

  if not entries then
    return function() end
  end

  local i = 0
  return function()
    i = i + 1
    if i <= #entries then
      return i, entries[i]
    end
  end
end

function c.rm(path, flags)
  assert(path, "path is not provided")

  local _path = Path.new(path)
  flags = flags or {}

  if _path:is_dir() then
    assert(flags.r, "cannot remove directory without -r flag: " .. path)

    for _, e in _read_dir_iter(_path:abspath()) do
      c.rm(_path:joinpath(e.name):abspath(), flags)
    end

    assert(vim.uv.fs_rmdir(_path:abspath()))
  else
    assert(vim.uv.fs_unlink(_path:abspath()))
  end
end

function c.mv(src, dst)
  assert(src, "src is not provided")
  assert(dst, "dst is not provided")

  local _src = Path.new(src)
  local _dst = Path.new(dst)

  pcall(c.mkdir, _dst:parent():abspath(), { p = true })

  for _, e in _read_dir_iter(_dst:abspath()) do
    c.mv(_src:joinpath(e.name):abspath(), _dst:joinpath(e.name):abspath())
  end

  vim.uv.fs_rename(_src:abspath(), _dst:abspath())
end

function c.cp(src, dst, flags)
  assert(src, "src is not provided")
  assert(dst, "dst is not provided")

  local _src = Path.new(src)
  local _dst = Path.new(dst)
  flags = flags or {}

  if _src:is_dir() then
    assert(flags.r, "cannot copy directory without -r flag: " .. src)

    pcall(c.mkdir, _dst:abspath(), { p = true })

    for _, e in _read_dir_iter(_src:abspath()) do
      c.cp(_src:joinpath(e.name):abspath(), _dst:joinpath(e.name):abspath(), flags)
    end
  else
    assert(vim.uv.fs_copyfile(_src:abspath(), _dst:abspath()))
  end
end

---@param path string
---@param is_dir boolean|nil
function c.create(path, is_dir)
  local _path = Path.new(path):norm()

  c.mkdir(_path:parent():abspath(), { p = true })

  if is_dir then
    c.mkdir(_path:abspath())
  else
    c.touch(_path:abspath())
  end
end

---@param path string
function c.delete(path)
  c.rm(Path.new(path):abspath(), { r = true })
end

---@param src string
---@param dst string
function c.move(src, dst)
  c.mv(Path.new(src):abspath(), Path.new(dst):abspath())
end

---@param src string
---@param dst string
function c.copy(src, dst)
  c.cp(Path.new(src):abspath(), Path.new(dst):abspath(), { r = true })
end

local function builder(fn)
  local meta = {
    __call = function(t, ...)
      local args = { ... }
      if not vim.tbl_isempty(t.flags or {}) then
        table.insert(args, t.flags)
      end

      return fn(util.unpack(args))
    end,

    __index = function(t, k)
      return setmetatable({
        flags = util.tbl_merge_force(t.flags or {}, { [k] = true }),
      }, getmetatable(t))
    end,
  }

  return setmetatable({ flags = {} }, meta)
end

return setmetatable({}, {
  __index = function(_, k)
    assert(c[k], "command not implemented: " .. k)
    return builder(c[k])
  end,
})
