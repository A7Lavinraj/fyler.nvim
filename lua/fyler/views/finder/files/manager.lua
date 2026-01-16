---@class FilesEntry
---@field ref_id integer
---@field open boolean
---@field updated boolean
---@field name string
---@field path string
---@field type string
---@field link string|nil
local Entry = {}
Entry.__index = Entry

---@class FilesEntryOpts : FilesEntry
---@field ref_id integer|nil

local FilesEntryManager = {
  _entries = {},
  _path_to_ref = {},
  _next_ref_id = 1,
}

---@param ref_id integer
---@return FilesEntry
function FilesEntryManager.get(ref_id)
  assert(ref_id, "cannot find entry without ref_id")
  assert(FilesEntryManager._entries[ref_id], "cannot locate entry with given ref_id")
  return FilesEntryManager._entries[ref_id]
end

---@param opts FilesEntryOpts
---@return integer
function FilesEntryManager.set(opts)
  assert(opts, "FilesEntry is required")

  local key = opts.link or opts.path

  if FilesEntryManager._path_to_ref[key] then return FilesEntryManager._path_to_ref[key] end

  opts.ref_id = FilesEntryManager._next_ref_id
  FilesEntryManager._next_ref_id = FilesEntryManager._next_ref_id + 1
  FilesEntryManager._entries[opts.ref_id] = opts
  FilesEntryManager._path_to_ref[key] = opts.ref_id

  return opts.ref_id
end

return FilesEntryManager
