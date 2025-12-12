local Path = require "fyler.lib.path"
local config = require "fyler.config"
local util = require "fyler.lib.util"

local M = {
  _instances = {}, ---@type table<string, uv.uv_fs_event_t>
}

---@param path string
---@param callback function
function M.register(path, callback)
  if not config.values.views.finder.watcher.enabled then
    return
  end

  local _path = Path.new(path)
  if not _path:exists() then
    return
  end

  M._instances[_path:normalize()] = assert(vim.uv.new_fs_event())
  M._instances[_path:normalize()]:start(_path:normalize(), {}, util.debounce_wrap(20, callback))
end

---@param path string
function M.unregister(path)
  if not config.values.views.finder.watcher.enabled then
    return
  end

  local _path = Path.new(path)
  local fs_event = M._instances[_path:normalize()]
  if not fs_event then
    return
  end

  fs_event:stop()
end

return M
