local Path = require("fyler.lib.path")
local Process = require("fyler.lib.process")
local config = require("fyler.config")
local util = require("fyler.lib.util")

local M = {}

local icon_map = {
  ["??"] = "Untracked",
  ["A "] = "Added",
  ["AM"] = "Added",
  [" M"] = "Modified",
  ["MM"] = "Modified",
  ["M "] = "Modified",
  [" D"] = "Deleted",
  ["D "] = "Deleted",
  ["MD"] = "Deleted",
  ["AD"] = "Deleted",
  ["R "] = "Renamed",
  ["RM"] = "Renamed",
  ["RD"] = "Renamed",
  ["C "] = "Copied",
  ["CM"] = "Copied",
  ["CD"] = "Copied",
  ["DD"] = "Conflict",
  ["AU"] = "Conflict",
  ["UD"] = "Conflict",
  ["UA"] = "Conflict",
  ["DU"] = "Conflict",
  ["AA"] = "Conflict",
  ["UU"] = "Conflict",
  ["!!"] = "Ignored",
}

local hl_map = {
  Untracked = "FylerGitUntracked",
  Added = "FylerGitAdded",
  Modified = "FylerGitModified",
  Deleted = "FylerGitDeleted",
  Renamed = "FylerGitRenamed",
  Copied = "FylerGitCopied",
  Conflict = "FylerGitConflict",
  Ignored = "FylerGitIgnored",
}

function M.map_entries_async(root_dir, entries, _next)
  M.build_modified_lookup_for_async(root_dir, function(modified_lookup)
    M.build_ignored_lookup_for_async(root_dir, entries, function(ignored_lookup)
      local status_map = util.tbl_merge_force(modified_lookup, ignored_lookup)
      local result = util.tbl_map(
        entries,
        function(e)
          return {
            config.values.views.finder.columns.git.symbols[icon_map[status_map[e]]] or "",
            hl_map[icon_map[status_map[e]]],
          }
        end
      )
      _next(result)
    end)
  end)
end

---@param dir string
---@param _next function
function M.build_modified_lookup_for_async(dir, _next)
  local process = Process.new({
    path = "git",
    args = { "-C", dir, "status", "--porcelain" },
  })

  process:spawn_async(function(code)
    local lookup = {}

    if code == 0 then
      for _, line in process:stdout_iter() do
        if line ~= "" then
          local symbol = line:sub(1, 2)
          local path = Path.new(dir):join(line:sub(4)):os_path()
          lookup[path] = symbol
        end
      end
    end

    _next(lookup)
  end)
end

---@param dir string
---@param stdin string|string[]
---@param _next function
function M.build_ignored_lookup_for_async(dir, stdin, _next)
  local process = Process.new({
    path = "git",
    args = { "-C", dir, "check-ignore", "--stdin" },
    stdin = table.concat(util.tbl_wrap(stdin), "\n"),
  })

  process:spawn_async(function(code)
    local lookup = {}

    if code == 0 then
      for _, line in process:stdout_iter() do
        if line ~= "" then lookup[line] = "!!" end
      end
    end

    _next(lookup)
  end)
end

return M
