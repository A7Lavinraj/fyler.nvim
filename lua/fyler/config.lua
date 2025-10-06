local util = require "fyler.lib.util"

---@class FylerConfigGitStatus
---@field enabled boolean
---@field symbols table<string, string>

---@alias FylerConfigIconProvider
---| "none"
---| "mini_icons"
---| "nvim_web_devicons"

---@alias FylerConfigFinderMapping
---| "CloseView"
---| "GotoCwd"
---| "GotoNode"
---| "GotoParent"
---| "Select"
---| "SelectSplit"
---| "SelectTab"
---| "SelectVSplit"
---| "CollapseAll"
---| "CollapseNode"

---@alias FylerConfigConfirmMapping
---| "Confirm"
---| "Discard"

---@class FylerConfigIndentScope
---@field enabled boolean
---@field group string
---@field marker string

---@alias FylerConfigBorder
---| "bold"
---| "double"
---| "none"
---| "rounded"
---| "shadow"
---| "single"
---| "solid"

---@class FylerConfigWin
---@field border FylerConfigBorder|string[]
---@field buf_opts table
---@field kind WinKind
---@field kinds table<WinKind|string, table>
---@field win_opts table

---@class FylerConfigViewsFinder
---@field close_on_select boolean
---@field confirm_simple boolean
---@field default_explorer boolean
---@field delete_to_trash boolean
---@field git_status FylerConfigGitStatus
---@field icon table<string, string>
---@field indentscope FylerConfigIndentScope
---@field mappings table<FylerConfigFinderMapping, string|function>
---@field track_current_buffer boolean
---@field win FylerConfigWin

---@class FylerConfigViewsConfirm
---@field mappings table<FylerConfigConfirmMapping, string|function>

---@class FylerConfigViews
---@field finder FylerConfigViewsFinder
---@field confirm FylerConfigViewsConfirm

---@class FylerConfig
---@field icon_provider FylerConfigIconProvider
---@field views FylerConfigViews

---@class FylerSetupIndentScope
---@field enabled boolean|nil
---@field group string|nil
---@field marker string|nil

---@class FylerSetupWin
---@field border FylerConfigBorder|string[]|nil
---@field buf_opts table|nil
---@field kind WinKind|nil
---@field kinds table<WinKind|string, table>|nil
---@field win_opts table|nil

---@class FylerSetup
---@field icon_provider FylerConfigIconProvider|nil
---@field views FylerConfigViews|nil

local M = {}

---@return string
local function border()
  if vim.fn.has "nvim-0.11" == 1 and vim.o.winborder ~= "" then
    return vim.o.winborder
  end

  return "rounded"
end

local function winhighlight()
  return table.concat({
    "Normal:FylerNormal",
    "FloatBorder:FylerBorder",
    "FloatTitle:FylerBorder",
  }, ",")
end

---@return FylerConfig
local function defaults()
  return {
    hooks = {},
    icon_provider = "mini_icons",
    views = {
      common = {
        win = {},
      },
      finder = {
        close_on_select = true,
        confirm_simple = false,
        default_explorer = false,
        icon = {
          directory_collapsed = nil,
          directory_empty = nil,
          directory_expanded = nil,
        },
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
        win = {
          border = border(),
          buf_opts = {
            filetype = "fyler",
            syntax = "fyler",
            buflisted = false,
            buftype = "acwrite",
            expandtab = true,
            shiftwidth = 2,
          },
          kind = "replace",
          kinds = {
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
            cursorline = false,
            number = false,
            relativenumber = false,
            winhighlight = winhighlight(),
            wrap = false,
          },
        },
      },
      confirm = {
        mappings = {
          ["y"] = "Confirm",
          ["n"] = "Discard",
        },
        win = {
          border = border(),
          buf_opts = {
            filetype = "FylerConfirm",
            buflisted = false,
            modifiable = false,
          },
          kind = "float",
          kinds = {
            float = {
              width = "0.4rel",
              height = "0.3rel",
              top = "0.35rel",
              left = "0.3rel",
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
            winhighlight = winhighlight(),
            wrap = false,
          },
        },
      },
    },
  }
end

---@param name string
---@param kind WinKind|nil
function M.view(name, kind)
  local view = vim.deepcopy(M.values.views[name] or {})
  view.win = require("fyler.lib.util").tbl_merge_force(view.win, view.win.kinds[kind or view.win.kind])
  return view
end

---@param name string
function M.rev_maps(name)
  local rev_maps = {}
  for k, v in pairs(M.values.views[name].mappings or {}) do
    if type(v) == "string" then
      local current = rev_maps[v]
      if current then
        table.insert(current, k)
      else
        rev_maps[v] = { k }
      end
    end
  end

  setmetatable(rev_maps, {
    __index = function()
      return "<nop>"
    end,
  })

  return rev_maps
end

---@param name string
function M.user_maps(name)
  local user_maps = {}
  for k, v in pairs(M.values.views[name].mappings or {}) do
    if type(v) == "function" then
      user_maps[k] = v
    end
  end

  return user_maps
end

-- Overwrites the defaults configuration options with user options
function M.setup(opts)
  opts = opts or {}

  ---@type FylerConfig
  M.values = util.tbl_merge_force(defaults(), opts)
end

return M
