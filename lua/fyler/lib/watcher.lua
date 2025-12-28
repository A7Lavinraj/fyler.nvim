local Path = require "fyler.lib.path"
local config = require "fyler.config"
local util = require "fyler.lib.util"

local M = {
  watchers = {},
}

local function debounce_key(path)
  return "watcher:" .. path
end

---@param path string
---@param id string
---@param callback function
function M.register(path, id, callback)
  if not config.values.views.finder.watcher.enabled then
    return
  end

  local p = Path.new(path)
  if not p:exists() then
    return
  end

  local normalized = p:normalize()
  local entry = M.watchers[normalized]

  if not entry then
    local fs = assert(vim.uv.new_fs_event())
    entry = {
      fs = fs,
      subs = {},
    }
    M.watchers[normalized] = entry

    fs:start(normalized, {}, function(...)
      local args = { ... }
      util.debounce(debounce_key(normalized), 200, function()
        for _, cb in pairs(entry.subs) do
          cb(unpack(args))
        end
      end)
    end)
  end

  entry.subs[id] = callback
end

---@param path string
---@param id string
function M.unregister(path, id)
  if not config.values.views.finder.watcher.enabled then
    return
  end

  local p = Path.new(path)
  local normalized = p:normalize()
  local entry = M.watchers[normalized]

  if not entry then
    return
  end

  entry.subs[id] = nil

  if vim.tbl_isempty(entry.subs) then
    entry.fs:stop()
    M.watchers[normalized] = nil
  end
end

function M.unregister_all()
  for path, entry in pairs(M.watchers) do
    entry.fs:stop()
    M.watchers[path] = nil
  end
end

return M
