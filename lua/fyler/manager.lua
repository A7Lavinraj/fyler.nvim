local log = require("fyler.log")

local M = {}

---@class FylerManager
---@field private instances table<number, FylerExplorerView>
---@field private tab_to_id table<number, number>
---@field private _instance FylerManager|nil

local FylerManager = {}
FylerManager.__index = FylerManager

-- Private table to store the singleton instance
local _instance = nil

function FylerManager:new()
  if _instance then return _instance end

  local instance = {
    instances = {},
    tab_to_id = {},
  }
  setmetatable(instance, self)
  self.__index = self

  _instance = instance

  vim.api.nvim_create_autocmd("TabClosed", {
    group = vim.api.nvim_create_augroup("FylerManager", { clear = true }),
    callback = function(args)
      vim.schedule(function()
        local current_tabs = vim.api.nvim_list_tabpages()
        local current_tabs_set = {}
        -- Create a set for O(1) lookups
        for _, tab in ipairs(current_tabs) do
          current_tabs_set[tab] = true
        end
        -- Single pass to identify and remove invalid entries
        for tabnr, explorer_id in pairs(_instance.tab_to_id) do
          if not current_tabs_set[tabnr] then
            _instance.tab_to_id[tabnr] = nil
            _instance.instances[explorer_id] = nil
          end
        end
      end)
    end,
  })

  return instance
end

---@return integer
function FylerManager:create_explorer()
  -- check if an explorer already exists for the current tab
  local tabnr = vim.api.nvim_get_current_tabpage()
  if self.tab_to_id[tabnr] then
    local existing_id = self.tab_to_id[tabnr]
    vim.notify("Explorer already exists for this tab", vim.log.levels.WARN)
    return existing_id
  end

  local tabnr = vim.api.nvim_get_current_tabpage()

  local existing_ids = vim.tbl_keys(self.instances)
  local unique_id = self:_assign_unique_id(existing_ids)

  local ExplorerView = require("fyler.views.explorer").ExplorerView
  local explorer = ExplorerView:new(unique_id)

  self.instances[unique_id] = explorer
  self.tab_to_id[tabnr] = unique_id

  return unique_id
end

---@param opts { cwd: string, enter: boolean, kind: FylerWinKind|string }
function FylerManager:open(opts)
  local explorer = self:get_current_explorer()
  if explorer then
    if explorer:is_visible() then
      explorer:focus()
      return
    else
      explorer:open(opts)
    end
  else
    vim.notify("Failed to open explorer: instance not found", vim.log.levels.ERROR)
  end
end

--- Get the explorer instance for the current tab, creating one if it doesn't exist
--- @return FylerExplorerView
function FylerManager:get_current_explorer()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local explorer_id = self.tab_to_id[tabnr]

  if not explorer_id then explorer_id = self:create_explorer() end

  return self.instances[explorer_id]
end

---@param file string|nil
function FylerManager:track_buffer(file)
  local explorer = self:get_current_explorer()
  if not explorer then
    log.error("No existing explorer")
    return
  end

  explorer:_action("try_focus_buffer") {
    file = file or vim.fn.expand("%:p"),
  }
end

function FylerManager:_assign_unique_id(existing_ids)
  -- Convert to a set for faster lookups
  local existing_set = {}
  for _, id in ipairs(existing_ids) do
    existing_set[id] = true
  end

  -- Find the first non-negative integer not in the set
  local candidate = 0
  while existing_set[candidate] do
    candidate = candidate + 1
  end

  return candidate
end

---@return FylerManager
function M.get_manager() return FylerManager:new() end

return M
