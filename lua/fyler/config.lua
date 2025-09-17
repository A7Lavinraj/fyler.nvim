local log = require "fyler.log"
local util = require "fyler.lib.util"

---@class FylerConfigGitStatus
---@field enabled boolean
---@field symbols table<string, string>

---@class FylerConfigHooks
---@field on_delete fun(path: string)|nil
---@field on_rename fun(src: string, dst: string)|nil
---@field on_highlight fun(groups: table, palette: Palette)|nil

---@alias FylerConfigIconProvider
---| "mini_icons"
---| "none"
---| "nvim_web_devicons"

---@alias FylerConfigExplorerMapping
---| "CloseView"
---| "GotoCwd"
---| "GotoNode"
---| "GotoParent"
---| "Select"
---| "SelectSplit"
---| "SelectTab"
---| "SelectVSplit"
---| "CollapseAll"

---@class FylerConfigIndentScope
---@field enabled boolean
---@field group string
---@field marker string

---@alias FylerConfigWinBorder
---| "bold"
---| "double"
---| "none"
---| "rounded"
---| "shadow"
---| "single"
---| "solid"

---@class FylerConfigWin
---@field border FylerConfigWinBorder|string[]
---@field buf_opts table
---@field kind WinKind
---@field kind_presets table<WinKind|string, table>
---@field win_opts table

---@class FylerConfigPopupPermissionKeys
---@field accept string|string[]
---@field reject string|string[]

---@class FylerConfigPopupPermission
---@field border FylerConfigWinBorder|string[]
---@field buf_opts table
---@field enter boolean
---@field height string
---@field kind WinKind
---@field keys FylerConfigPopupPermissionKeys
---@field left string
---@field top string
---@field width string

---@class FylerConfigPopup
---@field permission FylerConfigPopupPermission

---@class FylerConfig
---@field close_on_select boolean
---@field confirm_simple boolean
---@field default_explorer boolean
---@field git_status FylerConfigGitStatus
---@field hooks FylerConfigHooks
---@field icon table<string, string>
---@field icon_provider FylerConfigIconProvider
---@field indentscope FylerConfigIndentScope
---@field mappings table<string, FylerConfigExplorerMapping>
---@field popup FylerConfigPopup
---@field track_current_buffer boolean
---@field win FylerConfigWin

---@class FylerSetupOptionsHooks
---@field on_delete fun(path: string)|nil
---@field on_highlight fun(groups: table, palette: Palette)|nil
---@field on_rename fun(src: string, dst: string)|nil

---@class FylerSetupOptionsIndentScope
---@field enabled boolean|nil
---@field group string|nil
---@field marker string|nil

---@class FylerSetupOptionsWin
---@field border FylerConfigWinBorder|string[]|nil
---@field buf_opts table|nil
---@field kind WinKind|nil
---@field kind_presets table<WinKind|string, table>|nil
---@field win_opts table|nil

---@class FylerSetupOptionsPopupPermissionKeys
---@field accept string|string[]|nil
---@field reject string|string[]|nil

---@class FylerSetupOptionsPopupPermission
---@field border FylerConfigWinBorder|string[]|nil
---@field buf_opts table|nil
---@field enter boolean|nil
---@field height string|nil
---@field kind WinKind|nil
---@field keys FylerSetupOptionsPopupPermissionKeys|nil
---@field left string|nil
---@field top string|nil
---@field width string|nil

---@class FylerSetupOptionsPopup
---@field permission FylerSetupOptionsPopupPermission|nil

---@class FylerSetupOptions
---@field close_on_select boolean|nil
---@field confirm_simple boolean|nil
---@field default_explorer boolean|nil
---@field git_status FylerConfigGitStatus|nil
---@field hooks FylerSetupOptionsHooks|nil
---@field icon_provider FylerConfigIconProvider|nil
---@field indentscope FylerSetupOptionsIndentScope|nil
---@field mappings table<string, FylerConfigExplorerMapping>|nil
---@field popup FylerSetupOptionsPopup|nil
---@field track_current_buffer boolean|nil
---@field win FylerSetupOptionsWin|nil

local M = {}

---@return FylerConfig
local function defaults()
  return {
    close_on_select = true,
    confirm_simple = false,
    default_explorer = false,
    git_status = {
      enabled = true,
      symbols = {
        Untracked = "●",
        Added = "✚",
        Modified = "●",
        Deleted = "✖",
        Renamed = "➜",
        Copied = "C",
        Conflict = "‼",
        Ignored = "○",
      },
    },
    hooks = {
      on_delete = nil,
      on_rename = nil,
      on_highlight = nil,
    },
    icon = {
      directory_collapsed = nil,
      directory_empty = nil,
      directory_expanded = nil,
    },
    icon_provider = "mini_icons",
    indentscope = {
      enabled = true,
      group = "FylerIndentMarker",
      marker = "│",
    },
    mappings = {
      ["q"] = "CloseView",
      ["<CR>"] = "Select",
      ["<C-t>"] = "SelectTab",
      ["|"] = "SelectVSplit",
      ["-"] = "SelectSplit",
      ["^"] = "GotoParent",
      ["="] = "GotoCwd",
      ["."] = "GotoNode",
      ["#"] = "CollapseAll",
      ["<BS>"] = "CollapseNode",
    },
    track_current_buffer = true,
    popup = {
      permission = {
        border = vim.fn.has "nvim-0.11" == 1 and vim.o.winborder or "rounded",
        enter = true,
        height = "0.3rel",
        width = "0.4rel",
        left = "0.3rel",
        top = "0.35rel",
        kind = "float",
        keys = {
          accept = "y",
          reject = "n",
        },
        buf_opts = {
          modifiable = false,
        },
      },
    },
    win = {
      border = vim.fn.has "nvim-0.11" == 1 and vim.o.winborder or "rounded",
      buf_opts = {
        filetype = "fyler",
        syntax = "fyler",
        buflisted = false,
        buftype = "acwrite",
        expandtab = true,
        shiftwidth = 2,
      },
      kind = "replace",
      kind_presets = {
        float = {
          height = "0.7rel",
          width = "0.7rel",
          top = "0.1rel",
          left = "0.15rel",
        },
        replace = {},
        split_above = {
          height = "0.7rel",
        },
        split_above_all = {
          height = "0.7rel",
        },
        split_below = {
          height = "0.7rel",
        },
        split_below_all = {
          height = "0.7rel",
        },
        split_left = {
          width = "0.3rel",
        },
        split_left_most = {
          width = "0.3rel",
        },
        split_right = {
          width = "0.3rel",
        },
        split_right_most = {
          width = "0.3rel",
        },
      },
      win_opts = {
        concealcursor = "nvic",
        conceallevel = 3,
        cursorline = true,
        number = true,
        relativenumber = true,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatBorder",
        wrap = false,
      },
    },
  }
end

---@param kind WinKind
function M.build_win(kind)
  local win = M.values.win
  local kind_preset = M.values.win.kind_presets[kind]
  return util.tbl_merge_force(win, kind_preset)
end

function M.get_reversed_maps()
  local reversed_maps = {}
  for k, v in pairs(M.values.mappings) do
    if type(v) == "string" then
      local current = reversed_maps[v]
      if current then
        table.insert(current, k)
      else
        reversed_maps[v] = { k }
      end
    end
  end

  setmetatable(reversed_maps, { __index = function() return "<nop>" end })

  return reversed_maps
end

function M.get_user_mappings()
  local user_mappings = {}
  for k, v in pairs(M.values.mappings or {}) do
    if type(v) == "function" then user_mappings[k] = v end
  end

  return user_mappings
end

-- Type check for configuration option
---@param value any
---@param ref string|string[]
---@param allow_nil boolean|nil
local function check_type(value, ref, allow_nil)
  local are_matched
  if type(ref) == "table" then
    are_matched = util.if_any(ref, function(x) return type(value) == x end)
  elseif type(value) == ref then
    are_matched = true
  else
    are_matched = false
  end

  if are_matched or (ref == "callable" and vim.is_callable(value)) or (allow_nil and value == nil) then return end

  log.warn "[fyler.nvim] Your configuration might have some problems, Please run ':checkhealth fyler' for more details"
end

-- Overwrites the defaults configuration options with user options
function M.setup(opts)
  opts = opts or {}
  check_type(opts, "table")

  ---@type FylerConfig
  M.values = util.tbl_merge_force(defaults(), opts)

  local checks = {
    { M.values.hooks, "table" },
    { M.values.hooks.on_delete, "function", true },
    { M.values.hooks.on_rename, "function", true },
    { M.values.hooks.on_highlight, "function", true },
    { M.values.icon_provider, { "string", "function" } },
    { M.values.mappings, "table" },
    { M.values.close_on_select, "boolean" },
    { M.values.confirm_simple, "boolean" },
    { M.values.default_explorer, "boolean" },
    { M.values.git_status, "table" },
    { M.values.indentscope, "table" },
    { M.values.track_current_buffer, "boolean" },
    { M.values.popup, "table" },
    { M.values.popup.permission, "table" },
    { M.values.win, "table" },
  }

  for _, check in ipairs(checks) do
    check_type(util.unpack(check))
  end
end

return M
