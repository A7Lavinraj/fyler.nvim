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

  local normalized = _path:normalize()
  if M._instances[normalized] then
    M._instances[normalized]:stop()
    M._instances[normalized] = nil
  end

  M._instances[normalized] = assert(vim.uv.new_fs_event())
  M._instances[normalized]:start(normalized, {}, function(...)
    local args = { ... }
    -- TODO: Don't know is that a good practice to use function address as debounce ID
    util.debounce(tostring(callback), 200, function()
      callback(util.unpack(args))
    end)
  end)
end

---@param path string
function M.unregister(path)
  if not config.values.views.finder.watcher.enabled then
    return
  end

  local _path = Path.new(path)
  local normalized = _path:normalize()
  local fs_event = M._instances[normalized]

  if not fs_event then
    return
  end

  fs_event:stop()
  M._instances[normalized] = nil
end

function M.unregister_all()
  for path, fs_event in pairs(M._instances) do
    fs_event:stop()
    M._instances[path] = nil
  end
end

return M
