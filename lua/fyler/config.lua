--- CONFIGURATION
---
--- To setup Fyler put following code anywhere in your neovim runtime:
--- >lua
---   require("fyler").setup()
--- <
---
---@tag fyler.setup

--- INTEGRATIONS                                             *fyler.integrations*
---
--- icon                                                *fyler.integrations.icon*
---
--- Icon provider for file and directory icons.
---
--- >lua
---   integrations = {
---     icon = "mini_icons",  -- default
---   }
--- <
---
--- Providers:
--- - "mini_icons": Uses nvim-mini/mini.icons (default)
--- - "nvim_web_devicons": Uses nvim-tree/nvim-web-devicons
--- - "vim_nerdfont": Uses lambdalisue/vim-nerdfont
--- - "none": Disables icons
---
--- winpick                                          *fyler.integrations.winpick*
---
--- Window picker for selecting which window to open files in (split kinds).
---
--- >lua
---   integrations = {
---     winpick = "none",  -- or { provider = "none", opts = {} }
---   }
--- <
---
--- Providers:
--- - "none": Always opens in the last used window (default)
--- - "builtin": Floating labels on windows. Options: `chars` (default: "asdfghjkl;")
--- - "nvim-window-picker": Uses s1n7ax/nvim-window-picker. Options passed to `pick_window()`.
--- - "snacks": Uses folke/snacks.nvim picker. Options passed to `snacks.picker.util.pick_win()`.
--- - Custom function: `function(win_filter, onsubmit, opts)`
---   - `win_filter`: list of window IDs to exclude from selection (e.g. the fyler window)
---   - `onsubmit`: callback function, call with selected window ID or nil to cancel
---   - `opts`: the `opts` table from the winpick config
---
--- Custom winpick function example:
--- >lua
---   integrations = {
---     winpick = function(win_filter, onsubmit, opts)
---       local winid = require("window-picker").pick_window()
---       onsubmit(winid)
---     end,
---     opts = {}, -- this is what is passed as opts to the above function
---   }
--- <

local deprecated = require "fyler.deprecated"
local util = require "fyler.lib.util"

local config = {}

local DEPRECATION_RULES = {
  deprecated.rename("views.finder.git", "views.finder.columns.git"),
  deprecated.transform("views.finder.indentscope.marker", "views.finder.indentscope.markers", function()
    return { { "│", "FylerIndentMarker" }, { "└", "FylerIndentMarker" } }
  end),
}

---@class FylerConfigGitStatus
---@field enabled boolean
---@field symbols table<string, string>

---@alias FylerConfigIntegrationsIcon
---| "none"
---| "mini_icons"
---| "nvim_web_devicons"
---| "vim_nerdfont"

---@alias FylerConfigIntegrationsWinpickName
---| "none"
---| "builtin"
---| "nvim-window-picker"
---| "snacks"

---@alias FylerConfigIntegrationsWinpickFn fun(win_filter: integer[], onsubmit: fun(winid: integer|nil), opts: table)

---Options for the built-in window picker
---@class FylerConfigWinpickBuiltinOpts
---@field chars string|nil Characters used for window selection (default: "asdfghjkl;")

---@class FylerConfigWinpickTable
---@field provider FylerConfigIntegrationsWinpickName|FylerConfigIntegrationsWinpickFn
---@field opts FylerConfigWinpickBuiltinOpts|table<string, any>|nil

---Winpick config: either a provider name/function (shorthand) or a table with provider and opts
---@alias FylerConfigWinpick
---| FylerConfigIntegrationsWinpickName
---| FylerConfigIntegrationsWinpickFn
---| FylerConfigWinpickTable

---@class FylerConfigIntegrations
---@field icon FylerConfigIntegrationsIcon
---@field winpick FylerConfigWinpick

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

---@class FylerConfigWinKindOptions
---@field height string|number|nil
---@field width string|number|nil
---@field top string|number|nil
---@field left string|number|nil
---@field win_opts table<string, any>|nil

---@class FylerConfigWin
---@field border FylerConfigBorder|string[]
---@field bottom integer|string
---@field buf_opts table<string, any>
---@field footer string
---@field footer_pos string
---@field height integer|string
---@field kind WinKind
---@field kinds table<WinKind|string, FylerConfigWinKindOptions>
---@field left integer|string
---@field right integer|string
---@field title_pos string
---@field top integer|string
---@field width integer|string
---@field win_opts table<string, any>

---@class FylerConfigViewsFinder
---@field close_on_select boolean
---@field confirm_simple boolean
---@field default_explorer boolean
---@field delete_to_trash boolean
---@field git_status FylerConfigGitStatus
---@field icon table<string, string|nil>
---@field indentscope FylerConfigIndentScope
---@field mappings table<string, FylerConfigFinderMapping|function>
---@field mappings_opts vim.keymap.set.Opts
---@field follow_current_file boolean
---@field win FylerConfigWin

---@class FylerConfigViews
---@field finder FylerConfigViewsFinder

---@class FylerConfig
---@field hooks table<string, any>
---@field integrations FylerConfigIntegrations
---@field views FylerConfigViews

---@class FylerSetupIntegrations
---@field icon FylerConfigIntegrationsIcon|nil
---@field winpick FylerConfigWinpick|nil

---@class FylerSetupIndentScope
---@field enabled boolean|nil
---@field group string|nil
---@field marker string|nil

---@class FylerSetupWin
---@field border FylerConfigBorder|string[]|nil
---@field buf_opts table<string, any>|nil
---@field kind WinKind|nil
---@field kinds table<WinKind|string, FylerConfigWinKindOptions>|nil
---@field win_opts table<string, any>|nil

---@class FylerSetup
---@field hooks table<string, any>|nil
---@field integrations FylerSetupIntegrations|nil
---@field views FylerConfigViews|nil

--- DEFAULTS
---
--- To know more about plugin customization. visit:
--- `https://github.com/A7Lavinraj/fyler.nvim/wiki/configuration`
---
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---
---@tag fyler.defaults
function config.defaults()
  return {
    hooks = {},
    integrations = {
      icon = "mini_icons",
      winpick = "none",
    },
    views = {
      finder = {
        close_on_select = true,
        confirm_simple = false,
        default_explorer = false,
        delete_to_trash = false,
        columns_order = { "git", "diagnostic" },
        columns = {
          git = {
            enabled = true,
            symbols = {
              Untracked = "?",
              Added = "A",
              Modified = "M",
              Deleted = "D",
              Renamed = "R",
              Copied = "C",
              Conflict = "!",
              Ignored = " ",
            },
          },
          diagnostic = {
            enabled = true,
            symbols = {
              Error = "E",
              Warn = "W",
              Info = "I",
              Hint = "H",
            },
          },
        },
        icon = {
          directory_collapsed = nil,
          directory_empty = nil,
          directory_expanded = nil,
        },
        indentscope = {
          enabled = true,
          markers = {
            { "│", "FylerIndentMarker" },
            { "└", "FylerIndentMarker" },
          },
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
        mappings_opts = {
          nowait = false,
          noremap = true,
          silent = true,
        },
        follow_current_file = true,
        watcher = {
          enabled = false,
        },
        win = {
          border = vim.o.winborder == "" and "single" or vim.o.winborder,
          buf_opts = {
            bufhidden = "hide",
            buflisted = false,
            buftype = "acwrite",
            expandtab = true,
            filetype = "fyler",
            shiftwidth = 2,
            syntax = "fyler",
            swapfile = false,
          },
          kind = "replace",
          kinds = {
            float = {
              height = "70%",
              width = "70%",
              top = "10%",
              left = "15%",
            },
            replace = {},
            split_above = {
              height = "70%",
            },
            split_above_all = {
              height = "70%",
              win_opts = {
                winfixheight = true,
              },
            },
            split_below = {
              height = "70%",
            },
            split_below_all = {
              height = "70%",
              win_opts = {
                winfixheight = true,
              },
            },
            split_left = {
              width = "30%",
            },
            split_left_most = {
              width = "30%",
              win_opts = {
                winfixwidth = true,
              },
            },
            split_right = {
              width = "30%",
            },
            split_right_most = {
              width = "30%",
              win_opts = {
                winfixwidth = true,
              },
            },
          },
          win_opts = {
            concealcursor = "nvic",
            conceallevel = 3,
            cursorline = false,
            number = false,
            relativenumber = false,
            signcolumn = "no",
            winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC",
            wrap = false,
          },
        },
      },
    },
  }
end

---@param name string
---@param kind WinKind|nil
---@return FylerConfigViewsFinder
function config.view_cfg(name, kind)
  local view = vim.deepcopy(config.values.views[name] or {})
  view.win = require("fyler.lib.util").tbl_merge_force(view.win, view.win.kinds[kind or view.win.kind])
  return view
end

---@param name string
---@return table<string, string[]>
function config.rev_maps(name)
  local rev_maps = {}
  for k, v in pairs(config.values.views[name].mappings or {}) do
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
---@return table<string, function>
function config.usr_maps(name)
  local user_maps = {}
  for k, v in pairs(config.values.views[name].mappings or {}) do
    if type(v) == "function" then
      user_maps[k] = v
    end
  end

  return user_maps
end

---@param opts FylerSetup|nil
function config.setup(opts)
  opts = opts or {}

  config.values = util.tbl_merge_force(config.defaults(), deprecated.migrate(opts, DEPRECATION_RULES))

  local icon_provider = config.values.integrations.icon
  if type(icon_provider) == "string" then
    config.icon_provider = require("fyler.integrations.icon")[icon_provider]
  else
    config.icon_provider = icon_provider
  end

  local winpick_config = config.values.integrations.winpick
  -- Support shorthand: winpick = "provider-name" or winpick = function
  local winpick_provider = type(winpick_config) == "table" and winpick_config.provider or winpick_config
  config.winpick_opts = type(winpick_config) == "table" and winpick_config.opts or {}
  if type(winpick_provider) == "string" then
    config.winpick_provider = require("fyler.integrations.winpick")[winpick_provider]
  else
    config.winpick_provider = winpick_provider
  end

  for _, sub_module in ipairs {
    "fyler.autocmds",
    "fyler.hooks",
    "fyler.lib.hl",
  } do
    require(sub_module).setup(config)
  end
end

return config
