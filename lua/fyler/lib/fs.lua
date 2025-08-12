local List = require("fyler.lib.structs.list")
local Stack = require("fyler.lib.structs.stack")
local hooks = require("fyler.hooks")
local util = require("fyler.lib.util")

local a = require("fyler.lib.async")

local M = {}

local async = a.async
local await = a.await

local fn = vim.fn
local uv = vim.uv or vim.loop

---@return string
function M.getcwd() return uv.cwd() or fn.getcwd(0) end

---@param path string
---@return string
function M.normalize(path) return vim.fs.normalize(path) end

---@return string
function M.joinpath(...) return vim.fs.joinpath(...) end

---@param path string
---@return string
function M.abspath(path) return vim.fs.abspath(path) end

---@param path string
function M.relpath(base, path) return vim.fs.relpath(base, path) end

---@param path string
---@return boolean
function M.is_valid_path(path)
  local prefixless_path = string.gsub(path, "^fyler://", "")
  local _, err = uv.fs_stat(prefixless_path)
  return err == nil
end

---@param path string
---@return string|nil, string|nil
function M.resolve_link(path)
  local res_path = nil
  local res_type = nil
  while true do
    local stat = uv.fs_stat(path)
    if not stat then break end

    local linkdata = uv.fs_readlink(path)
    if not linkdata then
      res_path = path
      res_type = stat.type
      break
    end

    path = linkdata
  end

  return res_path, res_type
end

---@param path string
---@param cb fun(err: string|nil, items: table)
M.ls = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if not stat then return cb(stat_err, {}) end

  ---@diagnostic disable-next-line: param-type-mismatch
  local dir = uv.fs_opendir(path, nil, 1000)
  local items = {}

  while true do
    local _, entries = await(uv.fs_readdir, dir)
    if not entries then break end

    items = vim.list_extend(
      items,
      util.tbl_map(entries, function(entry)
        local link_path, link_type = M.resolve_link(M.joinpath(path, entry.name))
        return {
          name = entry.name,
          type = entry.type,
          path = M.joinpath(path, entry.name),
          link_path = link_path,
          link_type = link_type,
        }
      end)
    )
  end

  return cb(nil, items)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.touch = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if stat then return cb(stat_err, false) end

  local fd_err, fd = await(uv.fs_open, path, "a", 420)
  if not fd then return cb(fd_err, false) end

  return cb(await(uv.fs_close, fd))
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.rm = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if not stat or stat.type == "directory" then return cb(stat_err, false) end

  local unlink_err, success = await(uv.fs_unlink, path)
  if not success then return cb(unlink_err, false) end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.rm_r = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if not stat then return cb(stat_err, false) end

  local stack, list = Stack.new(), List.new()
  stack:push { path = path, type = stat.type }

  while not stack:is_empty() do
    local cur_entry = stack:pop()

    list:insert(1, cur_entry)

    if cur_entry.type == "directory" then
      local ls_err, entries = await(M.ls, cur_entry.path)
      if ls_err then return cb(ls_err, false) end

      for _, entry in ipairs(entries) do
        stack:push(entry)
      end
    end
  end

  for _, entry in ipairs(list:totable()) do
    if entry.type == "directory" then
      local rmdir_err, rmdir_success = await(M.rmdir, entry.path)
      if not rmdir_success then return cb(rmdir_err, false) end
    else
      local rm_err, rm_success = await(M.rm, entry.path)
      if not rm_success then return cb(rm_err, false) end
    end
  end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.mkdir = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if stat and stat.type == "directory" then return cb(stat_err, false) end

  local mkdir_err, success = await(uv.fs_mkdir, path, 493)
  if not success then return cb(mkdir_err, false) end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.mkdir_p = async(function(path, cb)
  local parts = util.filter_bl(vim.split(path, "/"))

  local is_win = fn.has("win32") == 1 or fn.has("win64") == 1

  local dir = is_win and parts[1] or ""

  local start_idx = is_win and 2 or 1
  for i = start_idx, #parts do
    dir = dir .. string.format("/%s", parts[i])

    local _, stat = await(uv.fs_stat, dir)
    if not stat then
      local mkdir_err, mkdir_success = await(M.mkdir, dir)
      if not mkdir_success then return cb(mkdir_err, false) end
    end
  end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.rmdir = async(function(path, cb)
  local stat_err, stat = await(uv.fs_stat, path)
  if not stat then return cb(stat_err, false) end

  local rmdir_err, success = await(uv.fs_rmdir, path)
  if not success then return cb(rmdir_err, false) end

  return cb(nil, true)
end)

---@param src_path string
---@param dst_path string
---@param cb fun(err: string|nil, success: boolean)
M.mv = async(function(src_path, dst_path, cb)
  local stat_err, src_stat = await(uv.fs_stat, src_path)
  if not src_stat then return cb(stat_err, false) end

  local _, dst_stat = await(uv.fs_stat, dst_path)
  if dst_stat then return cb("Destination path already exists", false) end

  local rename_err, rename_success = await(uv.fs_rename, src_path, dst_path)
  if not rename_success then return cb(rename_err, false) end

  return cb(nil, true)
end)

---@param src_path string
---@param dst_path string
---@param cb fun(err: string|nil, success: boolean)
M.cp = async(function(src_path, dst_path, cb)
  local stat_err, src_stat = await(uv.fs_stat, src_path)
  if not src_stat then return cb(stat_err, false) end

  if src_stat.type == "directory" then return cb("Source is a directory, use cp_r for recursive copy", false) end

  local _, dst_stat = await(uv.fs_stat, dst_path)
  if dst_stat then return cb("Destination path already exists", false) end

  local copyfile_err, copyfile_success = await(uv.fs_copyfile, src_path, dst_path, nil)
  if not copyfile_success then return cb(copyfile_err, false) end

  return cb(nil, true)
end)

---@param src_path string
---@param dst_path string
---@param cb fun(err: string|nil, success: boolean)
M.cp_r = async(function(src_path, dst_path, cb)
  local stat_err, src_stat = await(uv.fs_stat, src_path)
  if not src_stat then return cb(stat_err, false) end

  local _, dst_stat = await(uv.fs_stat, dst_path)
  if dst_stat then return cb("Destination path already exists", false) end

  local stk = Stack()
  stk:push {
    dst_path = dst_path,
    src_path = src_path,
    type = src_stat.type,
  }

  while not stk:is_empty() do
    local cur_entry = stk:pop()

    if cur_entry.type == "directory" then
      local mkdir_err, mkdir_success = await(M.mkdir_p, cur_entry.dst_path)
      if not mkdir_success then return cb(mkdir_err, false) end

      local ls_err, entries = await(M.ls, cur_entry.src_path)
      if ls_err then return cb(ls_err, false) end

      for _, entry in ipairs(entries) do
        local dst_entry_path = M.joinpath(cur_entry.dst_path, entry.name)
        stk:push {
          src_path = entry.path,
          dst_path = dst_entry_path,
          type = entry.type,
        }
      end
    else
      local copyfile_err, copyfile_success = await(uv.fs_copyfile, cur_entry.src_path, cur_entry.dst_path, nil)
      if not copyfile_success then return cb(copyfile_err, false) end
    end
  end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.create = async(function(path, cb)
  local mkdirp_err, mkdirp_success = await(M.mkdir_p, fn.fnamemodify(path, vim.endswith(path, "/") and ":h:h" or ":h"))
  if not mkdirp_success then return cb(mkdirp_err, false) end

  if vim.endswith(path, "/") then
    local mkdir_err, mkdir_success = await(M.mkdir, path)
    if not mkdir_success then return cb(mkdir_err, false) end
  else
    local touch_err, touch_success = await(M.touch, path)
    if not touch_success then return cb(touch_err, false) end
  end

  return cb(nil, true)
end)

---@param path string
---@param cb fun(err: string|nil, success: boolean)
M.delete = async(function(path, cb)
  local rm_r_err, rm_r_success = await(M.rm_r, path)
  if not rm_r_success then return cb(rm_r_err, false) end

  hooks.on_delete(path)

  return cb(nil, true)
end)

---@param src_path string
---@param dst_path string
---@param cb fun(err: string|nil, success: boolean)
M.move = async(function(src_path, dst_path, cb)
  local mkdirp_err, mkdirp_success = await(M.mkdir_p, fn.fnamemodify(dst_path, ":h"))
  if not mkdirp_success then return cb(mkdirp_err, false) end

  local mv_err, mv_success = await(M.mv, src_path, dst_path)
  if not mv_success then return cb(mv_err, false) end

  hooks.on_rename(src_path, dst_path)

  return cb(nil, true)
end)

---@param src_path string
---@param dst_path string
---@param cb fun(err: string|nil, success: boolean)
M.copy = async(function(src_path, dst_path, cb)
  local stat_err, src_stat = await(uv.fs_stat, src_path)
  if not src_stat then return cb(stat_err, false) end

  local _, dst_stat = await(uv.fs_stat, dst_path)
  if dst_stat then return cb("Destination path already exists", false) end

  local mkdirp_err, mkdirp_success = await(M.mkdir_p, fn.fnamemodify(dst_path, ":h"))
  if not mkdirp_success then return cb(mkdirp_err, false) end

  if src_stat.type == "directory" then
    local cp_r_err, cp_r_success = await(M.cp_r, src_path, dst_path)
    if not cp_r_success then return cb(cp_r_err, false) end
  else
    local copyfile_err, copyfile_success = await(uv.fs_copyfile, src_path, dst_path, nil)
    if not copyfile_success then return cb(copyfile_err, false) end
  end

  return cb(nil, true)
end)

return M
