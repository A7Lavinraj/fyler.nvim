--- INTRODUCTION
---
--- Fyler.nvim is a Neovim file manager plugin based on buffer-based file editing.
---
--- Why choose Fyler.nvim over |oil.nvim|?
--- - Provides a tree view.
--- - Users can have a full overview of their project without going back and forth
---   between directories.
---
--- GETTING STARTED
---
--- 1. Fyler must be setup correctly before use.
---
--- USAGE
---
--- Fyler can be used through commands or the Lua API.
---
--- COMMANDS
---
--- :Fyler dir=... kind=...
---
--- Parameters:
--- dir    Path to the directory to open
--- kind   Display method, one of:
---        - `float`
---        - `replace`
---        - `split_above`
---        - `split_above_all`
---        - `split_below`
---        - `split_below_all`
---        - `split_left`
---        - `split_left_most`
---        - `split_right`
---        - `split_right_most`
---
--- LUA API
---
--- >lua
---     local fyler = require("fyler")
---
---     -- Opens finder view with given options
---     fyler.open({ dir = "...", kind = "..." })
---
---     -- Toggles finder view with given options
---     fyler.toggle({ dir = "...", kind = "..." })
---
---     -- Focuses finder view
---     fyler.focus()
---
---     -- Focuses given file path or alternate buffer
---     fyler.navigate("...")
--- <
---
---@tag fyler.nvim

local M = {}

local did_setup = false

---@param opts FylerSetup|nil
function M.setup(opts)
  if vim.fn.has("nvim-0.11") == 0 then return vim.notify("Fyler requires at least NVIM 0.11") end

  if did_setup then return end

  require("fyler.config").setup(opts)

  did_setup = true

  local finder = setmetatable({}, { __index = function(_, k) return require("fyler.views.finder")[k] end })

  -- Fyler.API: Opens finder view with provided options
  M.open = function(args)
    args = args or {}
    finder.open(args.dir, args.kind)
  end

  -- Fyler.API: Closes current finder view
  M.close = finder.close

  -- Fyler.API: Toggles finder view with provided options
  M.toggle = function(args)
    args = args or {}
    finder.toggle(args.dir, args.kind)
  end

  -- Fyler.API: Focus finder view
  M.focus = finder.focus

  -- Fyler.API: Focuses given file path
  M.navigate = function(path) finder.navigate(path) end
end

return M
