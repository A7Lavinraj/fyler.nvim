local Path = require "fyler.lib.path"
local fs = require "fyler.lib.fs"

local M = {}

---@param opts {callback: function}
function M.get_trash_dir(opts)
  vim.schedule(function()
    opts.callback(Path.new(vim.uv.os_homedir() or vim.fn.expand "$HOME"):join(".Trash"):os_path())
  end)
end

---@param opts {dir: string, basename: string}
---@return string
function M.next_name(opts)
  if not Path.new(opts.dir):join(opts.basename):exists() then
    return opts.basename
  end

  local name, extension = vim.fn.fnamemodify(opts.basename, ":r"), vim.fn.fnamemodify(opts.basename, ":e")
  local counter = 1
  while true do
    local candidate = string.format("%s (%d).%s", name, counter, extension)
    if not Path.new(opts.dir):join(candidate):exists() then
      return candidate
    end

    counter = counter + 1
  end
end

---@param opts {path: string, callback: function}
function M.dump(opts)
  M.get_trash_dir {
    callback = function(trash_dir)
      local path_to_trash = Path.new(opts.path)
      local target_name = M.next_name {
        dir = trash_dir,
        basename = path_to_trash:basename(),
      }
      local target_path = Path.new(trash_dir):join(target_name)

      fs.mv({
        src = path_to_trash:os_path(),
        dst = target_path:os_path(),
      }, function(err)
        opts.callback(err)
      end)
    end,
  }
end

return M
