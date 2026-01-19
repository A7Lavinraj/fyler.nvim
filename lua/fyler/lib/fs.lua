local Path = require("fyler.lib.path")
local hooks = require("fyler.hooks")
local util = require("fyler.lib.util")

local M = {}

function M.write(opts, _next)
  local path = Path.new(opts.path):os_path()
  local data = opts.data or {}

  M.mkdir({
    path = Path.new(path):parent():os_path(),
    flags = { p = true },
  }, function(err)
    if err then
      pcall(_next, err)
      return
    end

    vim.uv.fs_open(path, "w", 420, function(err_open, fd)
      if err_open or not fd then
        pcall(_next, err_open)
        return
      end

      vim.uv.fs_write(fd, data, -1, function(err_write, bytes)
        if not bytes then
          vim.uv.fs_close(fd, function()
            M.rm({
              path = path,
            }, function() pcall(_next, string.format("Failed to write to %s: %s", path, err_write)) end)
          end)
        else
          vim.uv.fs_close(fd, function(err_close) pcall(_next, err_close) end)
        end
      end)
    end)
  end)
end

function M.ls(opts, _next)
  local path = Path.new(opts.path):os_path()

  vim.uv.fs_opendir(path, function(err_open, dir)
    if err_open or not dir then
      pcall(_next, err_open, nil)
      return
    end

    local contents = {}
    -- NOTE: Polling is necessary because `fs_readdir: async_version` list
    -- contents in chunks
    local function poll_entries()
      vim.uv.fs_readdir(dir, function(err_read, entries)
        if err_read then
          vim.uv.fs_closedir(dir, function() pcall(_next, err_read, nil) end)
          return
        end

        if entries and #entries > 0 then
          vim.list_extend(
            contents,
            util.tbl_map(entries, function(e)
              local entry_path_obj = Path.new(path):join(e.name)
              local entry_path, entry_type = entry_path_obj:res_link()
              if e.type == "link" then
                return {
                  name = e.name,
                  path = entry_path,
                  type = entry_type or "file",
                  link = entry_path_obj:posix_path(),
                }
              else
                return {
                  name = e.name,
                  type = e.type,
                  path = entry_path_obj:posix_path(),
                }
              end
            end)
          )

          poll_entries() -- Continue reading
        else
          vim.uv.fs_closedir(dir, function() pcall(_next, nil, contents) end)
        end
      end)
    end

    poll_entries()
  end, 1000)
end

function M.touch(opts, _next)
  local path = Path.new(opts.path):os_path()

  vim.uv.fs_open(path, "a", 420, function(err_open, fd)
    if err_open or not fd then
      pcall(_next, err_open)
      return
    end

    vim.uv.fs_close(fd, function(err_close) pcall(_next, err_close) end)
  end)
end

function M.mkdir(opts, _next)
  local flags = opts.flags or {}

  if flags.p then
    local prefixes = {}
    for _, prefix in Path.new(opts.path):iter() do
      table.insert(prefixes, prefix)
    end

    local function create_next(index)
      if index > #prefixes then return pcall(_next) end

      if Path.new(prefixes[index]):exists() then
        create_next(index + 1)
      else
        M.mkdir({ path = prefixes[index] }, function() create_next(index + 1) end)
      end
    end

    create_next(1)
  else
    vim.uv.fs_mkdir(Path.new(opts.path):os_path(), 493, function(err) pcall(_next, err) end)
  end
end

local function _read_dir_iter(opts, _next)
  local path = Path.new(opts.path):os_path()

  vim.uv.fs_opendir(path, function(err_open, dir)
    if err_open or not dir then
      pcall(_next, nil, function() end)
      return
    end

    vim.uv.fs_readdir(dir, function(err_read, entries)
      vim.uv.fs_closedir(dir, function()
        if err_read or not entries then
          pcall(_next, nil, function() end)
        else
          local i = 0
          pcall(_next, nil, function()
            i = i + 1
            if i <= #entries then return i, entries[i] end
          end)
        end
      end)
    end)
  end, 1000)
end

function M.rm(opts, _next)
  local path = Path.new(opts.path):os_path()
  local flags = opts.flags or {}

  flags = flags or {}

  if Path.new(path):is_directory() then
    assert(flags.r, "cannot remove directory without -r flag: " .. path)

    _read_dir_iter({
      path = path,
    }, function(err, iter)
      if err then
        pcall(_next, err)
        return
      end

      local entries = {}
      for _, e in iter do
        table.insert(entries, e)
      end

      local function remove_next(index)
        if index > #entries then
          vim.uv.fs_rmdir(path, function(err_rmdir) pcall(_next, err_rmdir) end)
          return
        end

        M.rm({
          path = Path.new(path):join(entries[index].name):os_path(),
          flags = flags,
        }, function(err)
          if err then
            pcall(_next, err)
            return
          end
          remove_next(index + 1)
        end)
      end

      remove_next(1)
    end)
  else
    vim.uv.fs_unlink(path, function(err) pcall(_next, err) end)
  end
end

function M.mv(opts, _next)
  local src = Path.new(opts.src):os_path()
  local dst = Path.new(opts.dst):os_path()

  M.mkdir({
    path = Path.new(dst):parent():os_path(),
    flags = { p = true },
  }, function()
    if Path.new(src):is_directory() then
      M.mkdir({
        path = dst,
        flags = { p = true },
      }, function()
        _read_dir_iter({
          path = src,
        }, function(err_iter, iter)
          if err_iter then
            pcall(_next, err_iter)
            return
          end

          local entries = {}
          for _, e in iter do
            table.insert(entries, e)
          end

          local function move_next(index)
            if index > #entries then
              vim.uv.fs_rmdir(src, function(err_rmdir) pcall(_next, err_rmdir) end)
              return
            end

            M.mv({
              src = Path.new(src):join(entries[index].name):os_path(),
              dst = Path.new(dst):join(entries[index].name):os_path(),
            }, function(err)
              if err then
                pcall(_next, err)
              else
                move_next(index + 1)
              end
            end)
          end

          move_next(1)
        end)
      end)
    else
      vim.uv.fs_rename(src, dst, function(err) pcall(_next, err) end)
    end
  end)
end

function M.cp(opts, _next)
  local src = Path.new(opts.src):os_path()
  local dst = Path.new(opts.dst):os_path()
  local flags = opts.flags or {}

  if Path.new(src):is_directory() then
    assert(flags.r, "cannot copy directory without -r flag: " .. src)

    M.mkdir({
      path = dst,
      flags = { p = true },
    }, function()
      _read_dir_iter({
        path = src,
      }, function(err_iter, iter)
        if err_iter then
          pcall(_next, err_iter)
          return
        end

        local entries = {}
        for _, e in iter do
          table.insert(entries, e)
        end

        local function copy_next(index)
          if index > #entries then
            pcall(_next)
            return
          end

          M.cp({
            src = Path.new(src):join(entries[index].name):os_path(),
            dst = Path.new(dst):join(entries[index].name):os_path(),
            flags = flags,
          }, function(err)
            if err then
              pcall(_next, err)
              return
            end
            copy_next(index + 1)
          end)
        end

        copy_next(1)
      end)
    end)
  else
    M.mkdir({
      path = Path.new(dst):parent():os_path(),
      flags = { p = true },
    }, function()
      vim.uv.fs_copyfile(src, dst, function(err) pcall(_next, err) end)
    end)
  end
end

function M.create(opts, _next)
  M.mkdir({
    path = Path.new(opts.path):parent():os_path(),
    flags = { p = true },
  }, function(err)
    if err then
      pcall(_next, err)
      return
    end

    if Path.new(opts.path):is_directory() then
      M.mkdir({ path = opts.path }, _next)
    else
      M.touch({ path = opts.path }, _next)
    end
  end)
end

function M.delete(opts, _next)
  M.rm({
    path = opts.path,
    flags = { r = true },
  }, function(err)
    if err then
      pcall(_next, err)
      return
    end

    vim.schedule(function() hooks.on_delete(opts.path) end)

    pcall(_next)
  end)
end

function M.move(opts, _next)
  M.mv({
    src = opts.src,
    dst = opts.dst,
  }, function(err)
    if err then
      pcall(_next, err)
      return
    end

    vim.schedule(function() hooks.on_rename(opts.src, opts.dst) end)

    pcall(_next)
  end)
end

function M.copy(opts, _next)
  M.cp({
    src = Path.new(opts.src):os_path(),
    dst = Path.new(opts.dst):os_path(),
    flags = { r = true },
  }, _next)
end

function M.trash(...)
  local trash = require("fyler.lib.trash")
  if trash then
    trash.dump(...)
  else
    vim.notify_once("TRASH is supported for this platform, fallback to DELETE", vim.log.levels.WARN)
    M.delete(...)
  end
end

return M
