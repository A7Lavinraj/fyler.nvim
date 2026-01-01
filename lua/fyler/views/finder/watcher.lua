local config = require "fyler.config"
local util = require "fyler.lib.util"

---@class Watcher
---@field paths table<string, { fs_event: uv.uv_fs_event_t, running: boolean }>
---@field finder Finder
local Watcher = {}
Watcher.__index = Watcher

local instance = {}

---@return Watcher
function Watcher.new(finder)
  local instance = {
    finder = finder,
    paths = {},
  }

  return setmetatable(instance, Watcher)
end

---@param dir string
function Watcher:start(dir)
  assert(vim.fn.isdirectory(dir) == 1, "Path must be provided to watch")

  if not config.values.views.finder.watcher.enabled then
    return self
  end

  if not self.paths[dir] then
    self.paths[dir] = {
      fs_event = assert(vim.uv.new_fs_event()),
      running = false,
    }
  end

  if self.paths[dir].running then
    return self
  end

  self.paths[dir].fs_event:start(dir, {}, function(err, filename)
    if err then
      return
    end

    if
      filename == nil
      or filename:match "index"
      or filename:match "ORIG_HEAD"
      or filename:match "FETCH_HEAD"
      or filename:match "COMMIT_EDITMSG"
      or vim.endswith(filename, ".lock")
    then
      return
    end

    util.debounce(string.format("watcher:%d_%d_%s", self.finder.win.winid, self.finder.win.bufnr, dir), 200, function()
      self.finder:dispatch_refresh {
        force_update = true,
        force_refresh = true,
      }
    end)
  end)

  self.paths[dir].running = true

  return self
end

function Watcher:enable()
  for dir in pairs(self.paths) do
    self:start(dir)
  end

  return self
end

function Watcher:stop(dir)
  assert(vim.fn.isdirectory(dir) == 1, "Path must be provided to watch")

  if not config.values.views.finder.watcher.enabled then
    return self
  end

  if self.paths[dir].running then
    self.paths[dir].fs_event:stop()
  end

  self.paths[dir].running = false

  return self
end

function Watcher:disable()
  for dir in pairs(self.paths) do
    self:stop(dir)
  end
  return self
end

function Watcher.register(finder)
  local key = string.format("fyler_watcher://%s?tab=%s", finder.dir, finder.tab)
  if not instance[key] then
    instance[key] = Watcher.new(finder)
  end
  return instance[key]
end

return Watcher
