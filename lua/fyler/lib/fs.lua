local Path = require "fyler.lib.path"
local hooks = require "fyler.hooks"
local util = require "fyler.lib.util"

local commands = {}

function commands.cwd()
  return vim.uv.cwd()
end

---@param path string
---@param data string|string[]
---@param callback function
function commands.write(path, data, callback)
  local _path = Path.new(path)

  commands.mkdir(_path:parent():normalize(), { p = true }, function(err)
    if err then
      return callback(err)
    end

    vim.uv.fs_open(_path:normalize(), "w", 420, function(err_open, fd)
      if err_open or not fd then
        return callback(err_open or "Failed to open file")
      end

      vim.uv.fs_write(fd, data, -1, function(err_write, bytes)
        if not bytes then
          vim.uv.fs_close(fd, function()
            commands.rm(_path:normalize(), nil, function()
              callback(string.format("Failed to write to %s: %s", path, err_write))
            end)
          end)
        else
          vim.uv.fs_close(fd, function(err_close)
            callback(err_close)
          end)
        end
      end)
    end)
  end)
end

---@param path string
---@param callback function
function commands.ls(path, callback)
  local _path = Path.new(path)
  if not (_path:exists() and _path:is_directory()) then
    return callback(nil, nil)
  end

  vim.uv.fs_opendir(_path:normalize(), function(err_open, dir)
    if err_open or not dir then
      return callback(err_open, nil)
    end

    local contents = {}
    -- NOTE: Polling is necessary because `fs_readdir: async_version` list contents in chunks
    local function poll_entries()
      vim.uv.fs_readdir(dir, function(err_read, entries)
        if err_read then
          vim.uv.fs_closedir(dir, function()
            callback(err_read, nil)
          end)
          return
        end

        if entries and #entries > 0 then
          vim.list_extend(
            contents,
            util.tbl_map(entries, function(e)
              local f = _path:join(e.name)
              local p, t = f:res_link()
              if e.type == "link" then
                return { name = e.name, path = p, type = t or "file", link = f:normalize() }
              else
                return { name = e.name, path = f:normalize(), type = e.type }
              end
            end)
          )

          poll_entries() -- Continue reading
        else
          vim.uv.fs_closedir(dir, function()
            callback(nil, contents)
          end)
        end
      end)
    end

    poll_entries()
  end, 1000)
end

---@param path string
---@param callback function
function commands.touch(path, callback)
  assert(path, "path is not provided")

  local _path = Path.new(path)

  vim.uv.fs_open(_path:normalize(), "a", 420, function(err_open, fd)
    if err_open or not fd then
      return callback(err_open or "Failed to open file")
    end

    vim.uv.fs_close(fd, function(err_close)
      callback(err_close)
    end)
  end)
end

---@param path string
---@param flags table|nil
---@param callback function
function commands.mkdir(path, flags, callback)
  if type(flags) == "function" then
    callback = flags
    flags = nil
  end

  assert(path, "path is not provided")

  local _path = Path.new(path)
  flags = flags or {}

  if flags.p then
    local prefixes = {}
    for _, prefix in _path:iter() do
      table.insert(prefixes, prefix)
    end

    local function create_next(index)
      if index > #prefixes then
        return callback(nil)
      end

      commands.mkdir(prefixes[index], nil, function()
        -- Ignore errors for parent dirs (they might exist)
        create_next(index + 1)
      end)
    end

    create_next(1)
  else
    vim.uv.fs_mkdir(_path:normalize(), 493, function(err)
      callback(err)
    end)
  end
end

local function _read_dir_iter(path, callback)
  vim.uv.fs_opendir(path, function(err_open, dir)
    if err_open or not dir then
      return callback(nil, function() end)
    end

    vim.uv.fs_readdir(dir, function(err_read, entries)
      vim.uv.fs_closedir(dir, function()
        if err_read or not entries then
          callback(nil, function() end)
        else
          local i = 0
          callback(nil, function()
            i = i + 1
            if i <= #entries then
              return i, entries[i]
            end
          end)
        end
      end)
    end)
  end, 1000)
end

---@param path string
---@param flags table|nil
---@param callback function
function commands.rm(path, flags, callback)
  if type(flags) == "function" then
    callback = flags
    flags = nil
  end

  assert(path, "path is not provided")

  local _path = Path.new(path)
  flags = flags or {}

  if _path:is_directory() then
    assert(flags.r, "cannot remove directory without -r flag: " .. path)

    _read_dir_iter(_path:normalize(), function(err, iter)
      if err then
        return callback(err)
      end

      local entries = {}
      for _, e in iter do
        table.insert(entries, e)
      end

      local function remove_next(index)
        if index > #entries then
          vim.uv.fs_rmdir(_path:normalize(), function(err_rmdir)
            callback(err_rmdir)
          end)
          return
        end

        commands.rm(_path:join(entries[index].name):normalize(), flags, function(err)
          if err then
            return callback(err)
          end
          remove_next(index + 1)
        end)
      end

      remove_next(1)
    end)
  else
    vim.uv.fs_unlink(_path:normalize(), function(err)
      callback(err)
    end)
  end
end

---@param src string
---@param dst string
---@param callback function
function commands.mv(src, dst, callback)
  assert(src, "src is not provided")
  assert(dst, "dst is not provided")

  local _src = Path.new(src)
  local _dst = Path.new(dst)

  assert(_src:exists(), "source does not exist: " .. src)

  commands.mkdir(_dst:parent():normalize(), { p = true }, function()
    -- Ignore error, parent might exist

    if _src:is_directory() then
      commands.mkdir(_dst:normalize(), { p = true }, function()
        -- Ignore error

        _read_dir_iter(_src:normalize(), function(err_iter, iter)
          if err_iter then
            return callback(err_iter)
          end

          local entries = {}
          for _, e in iter do
            table.insert(entries, e)
          end

          local function move_next(index)
            if index > #entries then
              vim.uv.fs_rmdir(_src:normalize(), function(err_rmdir)
                callback(err_rmdir)
              end)
              return
            end

            commands.mv(
              _src:join(entries[index].name):normalize(),
              _dst:join(entries[index].name):normalize(),
              function(err)
                if err then
                  return callback(err)
                end
                move_next(index + 1)
              end
            )
          end

          move_next(1)
        end)
      end)
    else
      vim.uv.fs_rename(_src:normalize(), _dst:normalize(), function(err)
        callback(err)
      end)
    end
  end)
end

---@param src string
---@param dst string
---@param flags table|nil
---@param callback function
function commands.cp(src, dst, flags, callback)
  if type(flags) == "function" then
    callback = flags
    flags = nil
  end

  assert(src, "src is not provided")
  assert(dst, "dst is not provided")

  local _src = Path.new(src)
  local _dst = Path.new(dst)
  flags = flags or {}

  assert(_src:exists(), "source does not exist: " .. src)

  if _src:is_directory() then
    assert(flags.r, "cannot copy directory without -r flag: " .. src)

    commands.mkdir(_dst:normalize(), { p = true }, function()
      -- Ignore error

      _read_dir_iter(_src:normalize(), function(err_iter, iter)
        if err_iter then
          return callback(err_iter)
        end

        local entries = {}
        for _, e in iter do
          table.insert(entries, e)
        end

        local function copy_next(index)
          if index > #entries then
            return callback(nil)
          end

          commands.cp(
            _src:join(entries[index].name):normalize(),
            _dst:join(entries[index].name):normalize(),
            flags,
            function(err)
              if err then
                return callback(err)
              end
              copy_next(index + 1)
            end
          )
        end

        copy_next(1)
      end)
    end)
  else
    commands.mkdir(_dst:parent():normalize(), { p = true }, function()
      -- Ignore error

      vim.uv.fs_copyfile(_src:normalize(), _dst:normalize(), function(err)
        callback(err)
      end)
    end)
  end
end

---@param path string
---@param is_dir boolean|nil
---@param callback function
function commands.create(path, is_dir, callback)
  if type(is_dir) == "function" then
    callback = is_dir
    is_dir = nil
  end

  local _path = Path.new(path)

  commands.mkdir(_path:parent():normalize(), { p = true }, function(err)
    if err then
      return callback(err)
    end

    if is_dir then
      commands.mkdir(_path:normalize(), {}, callback)
    else
      commands.touch(_path:normalize(), callback)
    end
  end)
end

---@param path string
---@param callback function
function commands.delete(path, callback)
  local _path = Path.new(path)
  commands.rm(_path:normalize(), { r = true }, function(err)
    if err then
      return callback(err)
    end

    vim.schedule(function()
      hooks.on_delete(_path:normalize())
    end)

    callback(nil)
  end)
end

---@param src string
---@param dst string
---@param callback function
function commands.move(src, dst, callback)
  local _src = Path.new(src)
  local _dst = Path.new(dst)
  commands.mv(_src:normalize(), _dst:normalize(), function(err)
    if err then
      return callback(err)
    end

    vim.schedule(function()
      hooks.on_rename(_src:normalize(), _dst:normalize())
    end)

    callback(nil)
  end)
end

---@param src string
---@param dst string
---@param callback function
function commands.copy(src, dst, callback)
  commands.cp(Path.new(src):normalize(), Path.new(dst):normalize(), { r = true }, callback)
end

---@param src string
---@param callback function
function commands.trash(src, callback)
  require("fyler.lib.trash").dump(src, callback)
end

local function builder(fn)
  local meta = {
    __call = function(t, ...)
      local args = { ... }
      local callback = nil

      -- Check if last arg is a callback
      if type(args[#args]) == "function" then
        callback = table.remove(args)
      end

      -- Add flags if they exist and are not empty
      if t.flags and not vim.tbl_isempty(t.flags) then
        table.insert(args, t.flags)
      end

      -- Add callback back at the end
      if callback then
        table.insert(args, callback)
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
    assert(commands[k], "command not implemented: " .. k)
    return builder(commands[k])
  end,
})
