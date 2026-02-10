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
local PathToRefId = {} -- entry path (including symlink path) -> ref_id
local ResolvedPathToRefId = {} -- resolved path -> ref_id (for follow_current_file on symlinks)
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
    if opts.link then ResolvedPathToRefId[opts.path] = ref_id end
    return ref_id
  end

  ref_id = NextRefId
  NextRefId = NextRefId + 1

  local new_entry = util.tbl_merge_force({}, DEFAULT_ENTRY)
  new_entry = util.tbl_merge_force(new_entry, opts)
  new_entry.ref_id = ref_id

  PathToRefId[path] = ref_id
  if opts.link then ResolvedPathToRefId[opts.path] = ref_id end
  Entries[ref_id] = new_entry

  return ref_id
end

---@param resolved_path string
---@return string|nil
function M.find_link_path_from_resolved(resolved_path)
  local ref_id = ResolvedPathToRefId[resolved_path]
  if ref_id then
    local entry = Entries[ref_id]
    if entry and entry.link then return entry.link end
  end

  local parent = resolved_path
  while parent do
    parent = parent:match("^(.*)/[^/]+$")
    if not parent or parent == "/" then break end

    ref_id = ResolvedPathToRefId[parent]
    if ref_id then
      local entry = Entries[ref_id]
      if entry and entry.link then return entry.link .. resolved_path:sub(#parent + 1) end
    end
  end
end
return M
