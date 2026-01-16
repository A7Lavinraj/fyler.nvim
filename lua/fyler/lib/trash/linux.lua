local Path = require("fyler.lib.path")
local fs = require("fyler.lib.fs")

local M = {}

---@param opts {dir: string, basename: string}
---@return string
function M.next_name(opts)
  if not Path.new(opts.dir):join(opts.basename):exists() then return opts.basename end

  local name, extension = vim.fn.fnamemodify(opts.basename, ":r"), vim.fn.fnamemodify(opts.basename, ":e")
  local counter = 1
  while true do
    local candidate = string.format("%s (%d).%s", name, counter, extension)
    if not Path.new(opts.dir):join(candidate):exists() then return candidate end
    counter = counter + 1
  end
end

function M.dump(opts, _next)
  local path_to_trash = Path.new(opts.path)
  local dir = Path.new(vim.F.if_nil(vim.env.XDG_DATA_HOME, vim.fs.joinpath(vim.fn.expand("$HOME"), ".local", "share")))
    :join("Trash")
  local files, info = dir:join("files"):os_path(), dir:join("info"):os_path()

  fs.mkdir({
    path = files,
    flags = { p = true },
  }, function(err)
    if err then return pcall(_next, err) end

    fs.mkdir({
      path = info,
      flags = { p = true },
    }, function(err_info)
      if err_info then return pcall(_next, err_info) end

      local target_name = M.next_name({
        dir = files,
        basename = path_to_trash:basename(),
      })
      local target_path = Path.new(files):join(target_name)
      local trash_info = table.concat({
        "[Trash Info]",
        string.format("Path=%s", path_to_trash:os_path()),
        string.format("DeletionDate=%s", os.date("%Y-%m-%dT%H:%M:%S")),
      }, "\n")

      -- Writing meta data to "%.trashinfo"
      fs.write({
        path = Path.new(info):join(target_name .. ".trashinfo"):os_path(),
        data = trash_info,
      }, function(err_write)
        if err_write then return pcall(_next, err_write) end

        -- Move to trash directory
        fs.mv({
          src = path_to_trash:os_path(),
          dst = target_path:os_path(),
        }, function(err_mv) return pcall(_next, err_mv) end)
      end)
    end)
  end)
end

return M
