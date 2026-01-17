local util = require("fyler.lib.util")

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

---@class FilesEntryOpts
---@field ref_id integer|nil
---@field open boolean|nil
---@field updated boolean|nil
---@field name string|nil
---@field path string
---@field type string|nil
---@field link string|nil

local M = {}

local Entries = {}
local PathToRefId = {}
local NextRefId = 1

local DEFAULT_ENTRY = {
  open = false,
  updated = false,
  type = "file",
}

---@param ref_id integer
---@return FilesEntry
function M.get(ref_id)
  assert(ref_id, "cannot find entry without ref_id")
  local entry = Entries[ref_id]
  assert(entry, "cannot locate entry with given ref_id")
  return entry
end

---@param opts FilesEntryOpts
---@return integer
function M.set(opts)
  assert(opts and opts.path, "FilesEntry requires at least a path")

  local path = opts.link or opts.path
  local ref_id = PathToRefId[path]
  local entry = ref_id and Entries[ref_id]

  if entry then
    Entries[ref_id] = util.tbl_merge_force(entry, opts)
    return ref_id
  end

  ref_id = NextRefId
  NextRefId = NextRefId + 1

  local new_entry = util.tbl_merge_force({}, DEFAULT_ENTRY)
  new_entry = util.tbl_merge_force(new_entry, opts)
  new_entry.ref_id = ref_id

  PathToRefId[path] = ref_id
  Entries[ref_id] = new_entry

  return ref_id
end

return M
