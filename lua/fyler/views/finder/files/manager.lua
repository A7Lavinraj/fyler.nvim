local util = require "fyler.lib.util"

---@class Entry
---@field ref_id integer
---@field open boolean
---@field name string
---@field path string
---@field type string
---@field link string|nil
local Entry = {}
Entry.__index = Entry

---@class EntryOpts : Entry
---@field ref_id integer|nil

---@param opts EntryOpts
---@return Entry
function Entry.new(opts)
  return setmetatable(util.tbl_merge_force({}, opts), Entry)
end

---@return boolean
function Entry:isdir()
  return self.type == "directory"
end

---@class EntryManager
---@field _entries table<integer, Entry>
---@field _path_to_ref table<string, integer>
---@field _next_ref_id integer
local EntryManager = {}
EntryManager.__index = EntryManager

---@return EntryManager
function EntryManager.new()
  local instance = {
    _entries = {},
    _path_to_ref = {},
    _next_ref_id = 1,
  }

  setmetatable(instance, EntryManager)
  return instance
end

---@param ref_id integer
---@return Entry
function EntryManager:get(ref_id)
  assert(ref_id, "cannot find entry without ref_id")
  assert(self._entries[ref_id], "cannot locate entry with given ref_id")

  return self._entries[ref_id]
end

---@param opts EntryOpts
---@return integer
function EntryManager:set(opts)
  local key = opts.link or opts.path

  if self._path_to_ref[key] then
    return self._path_to_ref[key]
  end

  opts.ref_id = self._next_ref_id
  self._next_ref_id = self._next_ref_id + 1
  self._entries[opts.ref_id] = Entry.new(opts)
  self._path_to_ref[key] = opts.ref_id

  return opts.ref_id
end

function EntryManager:reset()
  self._entries = {}
  self._path_to_ref = {}
  self._next_ref_id = 1
end

return EntryManager
