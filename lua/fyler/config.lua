local util = require("fyler.lib.util")

---@class FylerConfigHooks
---@field on_delete fun(path: string)|nil
---@field on_rename fun(src_path: string, dst_path: string)|nil
---@field on_highlights fun(hl_groups: table, palette: table)|nil

---Defines icon provider to various views. It is a function with following definition:
---```
---fun(type: string, name: string): string, string
---```
---Builtin options: `mini-icons`, `nvim-web-devicons`
---@alias FylerConfigIconProvider "mini-icons"| "nvim-web-devicons"|fun(type: string, name: string): string, string

---@class FylerConfigIndentScope
---@field enabled boolean Enable or disable indentation markers
---@field group string Change highlight group
---@field marker string Change marker char

---@alias FylerConfigMappingsExplorer
---| "CloseView" Close explorer view
---| "Select" Select item under the cursor
---| "SelectTab" Open file under the cursor in new tab
---| "SelectVSplit" Open file under the cursor in vertical split
---| "SelectSplit" Open file under the cursor horizontal split
---| "GotoParent" Jump to parent directory
---| "GotoCwd" Jump to current working directory
---| "GotoNode" Jump to node under cursor

---@alias FylerConfigMappingsConfirm
---| "Confirm" Confirm actions
---| "Discard" Discard actions

---@class FylerConfigMappings
---@field confirm table<string, FylerConfigMappingsConfirm>
---@field explorer table<string, FylerConfigMappingsExplorer>

---@alias FylerConfigViewWinKindPreset { height: string, width: string }

---@class FylerConfigViewWin
---@field border string Window border style (for more info ':help winborder')
---@field buf_opts table<string, any> Buffer options
---@field kind FylerWinKind Window kind
---@field kind_presets table<string, FylerConfigViewWinKindPreset> Window kind
---@field win_opts table<string, any> Window options

---@class FylerConfigViewConfirm
---@field win FylerConfigViewWin

---@class FylerConfigViewExplorer
---@field close_on_select boolean
---@field confirm_simple boolean
---@field default_explorer boolean
---@field git_status boolean
---@field indentscope FylerConfigIndentScope
---@field win FylerConfigViewWin

---@class FylerConfigViews
---@field confirm FylerConfigViewConfirm
---@field explorer FylerConfigViewExplorer

---@class FylerConfigDefaults
---@field hooks FylerConfigHooks
---@field icon_provider FylerConfigIconProvider
---@field mappings FylerConfigMappings
---@field views FylerConfigViews

---@class FylerConfig : FylerConfigDefaults
---@field hooks FylerConfigHooks|nil
---@field icon_provider FylerConfigIconProvider|nil
---@field mappings FylerConfigMappings|nil
---@field views FylerConfigViews|nil

local M = {}

-- Default configuration used by "Fyler.nvim" which will get overwrite by user
---@type FylerConfigDefaults
local defaults = {
  -- Hooks are predefined functions which gets invoke on particular events
  hooks = {
    -- "on_delete" hook will get triggered when a file gets deleted by "Fyler.nvim"
    on_delete = nil,

    -- "on_rename" hook will get triggered when a file gets renamed by "Fyler.nvim"
    on_rename = nil,

    -- "on_highlights" hook will get triggered when a setting highlight groups by "Fyler.nvim"
    on_highlights = nil,
  },

  -- "icon_provider" defines the icon generator along with it's highlight group. It can be one the following:
  -- 1. "none"
  -- 2. "minimal"
  -- 3. "mini-icons"
  -- 4. "nvim-web-devicons"
  -- or it could be a function with definition `fun(type: string, name: string): string, string`
  icon_provider = "mini-icons",

  -- Mappings are local to their "view" and only **normal mode** mappings are allowed for now
  mappings = {
    explorer = {
      ["q"] = "CloseView",
      ["<CR>"] = "Select",
      ["<C-t>"] = "SelectTab",
      ["|"] = "SelectVSplit",
      ["-"] = "SelectSplit",
      ["^"] = "GotoParent",
      ["="] = "GotoCwd",
      ["."] = "GotoNode",
    },
    confirm = {
      ["y"] = "Confirm",
      ["n"] = "Discard",
    },
  },
  -- "views" is a map to corresponding configuration
  views = {
    confirm = {
      win = {
        -- Border style
        border = "single",

        -- Buffer options
        buf_opts = {
          buflisted = false,
          modifiable = false,
        },

        -- Window kind, can be one the following:
        -- "float"
        -- "replace"
        -- "split_above"
        -- "split_above_all"
        -- "split_below"
        -- "split_below_all"
        -- "split_left"
        -- "split_left_most"
        -- "split_right"
        -- "split_right_most"
        kind = "float",

        -- Each preset defines the dimensions and positioning of corresponding window kind
        kind_presets = {
          float = {
            height = "0.3rel",
            width = "0.4rel",
            top = "0.3rel",
            left = "0.3rel",
          },
          replace = {},
          split_above = {
            height = "0.5rel",
          },
          split_above_all = {
            height = "0.5rel",
          },
          split_below = {
            height = "0.5rel",
          },
          split_below_all = {
            height = "0.5rel",
          },
          split_left = {
            width = "0.5rel",
          },
          split_left_most = {
            width = "0.5rel",
          },
          split_right = {
            width = "0.5rel",
          },
          split_right_most = {
            width = "0.5rel",
          },
        },
        win_opts = {
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
          wrap = false,
        },
      },
    },
    explorer = {
      -- Close explorer on selecting a file
      close_on_select = true,

      -- Skips confirmation for simple edits(CREATE <= 5 && DELETE == 0 && MOVE <= 1 && COPY <= 1)
      confirm_simple = false,

      -- Replace most of the NETRW commands
      default_explorer = false,

      -- Git symbols
      git_status = true,

      -- Indentation markers
      indentscope = {
        enabled = true,
        group = "FylerIndentMarker",
        marker = "│",
      },

      -- Auto current buffer tracking
      track_current_buffer = true,

      win = {
        border = "single",
        buf_opts = {
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
            top = "0.15rel",
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
          cursorline = true,
          number = true,
          relativenumber = true,
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
          wrap = false,
        },
      },
    },
  },
}

-- Returns configuration for a particular "view" and "kind"
---@param name string
---@param kind FylerWinKind|nil
function M.get_view_config(name, kind)
  assert(name, "name is required")
  local view = vim.deepcopy(M.values.views[name])
  local preset = view.win.kind_presets[kind or view.win.kind]
  view.win = util.tbl_merge_keep(view.win, preset)
  return view
end

-- Returns key mappings for a particular "view"
---@param name string
function M.get_mappings(name)
  assert(name, "name is required")
  return M.values.mappings[name]
end

-- Type check for configuration option
---@param name string
---@param value any
---@param ref string|string[]
---@param allow_nil boolean|nil
local function check_type(name, value, ref, allow_nil)
  local are_matched = (function()
    if type(ref) == "table" then
      return util.if_any(ref, function(x) return type(value) == x end)
    elseif type(value) == ref then
      return true
    else
      return false
    end
  end)()

  if are_matched or (ref == "callable" and vim.is_callable(value)) or (allow_nil and value == nil) then return end

  error(string.format("(fyler.nvim) `%s` should be %s, not %s", name, ref, type(value)))
end

-- Overwrites the defaults configuration options with user options
---@param config FylerConfig|nil
function M.setup(config)
  config = config or {}
  check_type("config", config, "table")

  local values = vim.tbl_deep_extend("force", defaults, config)
  for _, view_name in ipairs {
    "confirm",
    "explorer",
  } do
    local win = values.views[view_name].win
    check_type(
      string.format("config.views.%s.win.kind_presets.%s", view_name, win.kind),
      win.kind_presets[win.kind],
      "table"
    )

    for _, kind_preset_name in ipairs {
      "float",
      "replace",
      "split_above",
      "split_above_all",
      "split_below",
      "split_below_all",
      "split_left",
      "split_left_most",
      "split_right",
      "split_right_most",
    } do
      local kind_preset = values.views[view_name].win.kind_presets[kind_preset_name]
      check_type(string.format("config.views.%s.%s", view_name, kind_preset_name), kind_preset, "table")
      check_type(
        string.format("config.views.%s.%s.height", view_name, kind_preset_name),
        kind_preset.height,
        "string",
        kind_preset_name ~= "float"
      )
      check_type(
        string.format("config.views.%s.%s.width", view_name, kind_preset_name),
        kind_preset.width,
        "string",
        kind_preset_name ~= "float"
      )
    end
  end

  local checks = {
    { "config.hooks", values.hooks, "table" },
    { "config.icon_provider", values.icon_provider, { "string", "function" } },
    { "config.mappings", values.mappings, "table" },
    { "config.mappings.confirm", values.mappings.confirm, "table" },
    { "config.mappings.explorer", values.mappings.explorer, "table" },
    { "config.views", values.views, "table" },
    { "config.views.confirm", values.views.confirm, "table" },
    { "config.views.confirm.kind", values.views.confirm.win.kind, "string" },
    { "config.views.confirm.win.border", values.views.confirm.win.border, "string" },
    { "config.views.confirm.win.buf_opts", values.views.confirm.win.buf_opts, "table" },
    { "config.views.confirm.win.win_opts", values.views.confirm.win.win_opts, "table" },
    { "config.views.explorer", values.views.explorer, "table" },
    { "config.views.explorer.close_on_select", values.views.explorer.close_on_select, "boolean" },
    { "config.views.explorer.confirm_simple", values.views.explorer.confirm_simple, "boolean" },
    { "config.views.explorer.default_explorer", values.views.explorer.default_explorer, "boolean" },
    { "config.views.explorer.git_status", values.views.explorer.git_status, "boolean" },
    { "config.views.explorer.indentscope", values.views.explorer.indentscope, "table" },
    { "config.views.explorer.indentscope.enabled", values.views.explorer.indentscope.enabled, "boolean" },
    { "config.views.explorer.indentscope.group", values.views.explorer.indentscope.group, "string" },
    { "config.views.explorer.indentscope.marker", values.views.explorer.indentscope.marker, "string" },
    { "config.views.explorer.kind", values.views.explorer.win.kind, "string" },
    { "config.views.explorer.win.border", values.views.explorer.win.border, "string" },
    { "config.views.explorer.win.buf_opts", values.views.explorer.win.buf_opts, "table" },
    { "config.views.explorer.win.win_opts", values.views.explorer.win.win_opts, "table" },
  }

  for _, check in ipairs(checks) do
    check_type(util.unpack(check))
  end

  M.values = values
end

return M
