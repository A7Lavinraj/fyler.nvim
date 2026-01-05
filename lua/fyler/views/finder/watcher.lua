local Path = require "fyler.lib.path"
local config = require "fyler.config"
local util = require "fyler.lib.util"

---@class Watcher
---@field paths table<string, { fsevent: uv.uv_fs_event_t, running: boolean }>
---@field finder Finder
local Watcher = {}
Watcher.__index = Watcher

local instance = {}

---@return Watcher
function Watcher.new(finder)
  return setmetatable({ finder = finder, paths = {} }, Watcher)
end

---@param dir string
function Watcher:start(dir)
  if not dir then
    return
  end

  if not Path.new(dir):is_directory() then
    self.paths[dir] = nil
    return
  end

  if not config.values.views.finder.watcher.enabled then
    return self
  end

  if not self.paths[dir] then
    self.paths[dir] = {
      fsevent = assert(vim.uv.new_fs_event()),
      running = false,
    }
  end

  if self.paths[dir].running then
    return self
  end

  self.paths[dir].fsevent:start(dir, {}, function(err, filename)
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
      self.finder:dispatch_refresh { force_update = true }
    end)
  end)

  self.paths[dir].running = true
end

function Watcher:enable()
  for dir in pairs(self.paths) do
    self:start(dir)
  end
end

function Watcher:stop(dir)
  if not dir then
    return
  end

  if not Path.new(dir):is_directory() then
    self.paths[dir] = nil
    return
  end

  if not config.values.views.finder.watcher.enabled then
    return self
  end

  if self.paths[dir].running then
    self.paths[dir].fsevent:stop()
  end

  self.paths[dir].running = false
end

---@param should_clean boolean|nil
function Watcher:disable(should_clean)
  for dir in pairs(self.paths) do
    self:stop(dir)
  end

  if should_clean then
    self.paths = {}
  end
end

function Watcher.register(finder)
  local uri = finder.uri
  if not instance[uri] then
    instance[uri] = Watcher.new(finder)
  end
  return instance[uri]
end

return Watcher
