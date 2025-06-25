local M = {}

local count = 0
local store = {}

---@alias FileType 'directory' | 'file' | 'link' | string

---@class FileMetadata
---@field type FileType
---@field name string
---@field path string
---@field links_to? { path: string, type: FileType? }
---@field key number
local Metadata = {}
Metadata.__index = Metadata

function Metadata:is_directory()
  return self.type == "directory" or (self.type == "link" and self.links_to.type == "directory")
end

function Metadata:is_valid_link()
  return self.type == "link" and self.links_to.type ~= nil
end

function Metadata:is_broken_link()
  return self.type == "link" and self.links_to.type == nil
end

function Metadata:resolved_type()
  return self.type == "link" and self.links_to.path or self.path
end

function Metadata:resolved_path()
  return self.type == "link" and self.links_to.path or self.path
end

---@param key integer
---@return FileMetadata
function M.get(key)
  return setmetatable(vim.deepcopy(store[key]), Metadata)
end

---@param tbl { type: FileType, name: string, path: string }
---@return integer
function M.set(tbl)
  count = count + 1
  store[count] = tbl
  return count
end

function M.debug()
  for k, v in pairs(store) do
    print(k, vim.inspect(v))
  end
end

return M
