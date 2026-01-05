--- INTRODUCTION
---
--- Fyler.nvim is a neovim file manager plugin based on buffer based file editing.
---
--- Why Fyler.nvim over |oil.nvim|?
--- - It provides tree view.
--- - Users can now have full overview of project without going back and
---   forth between directories.
---
--- Getting started with Fyler:
--- 1. Run `:checkhealth fyler` to make sure everything is in right place.
--- 2. Fyler must be setup correctly before used. See |Fyler.Setup|
---
--- USAGE
---
--- Fyler can be used through commands:
---
--- `:Fyler dir=... kind=...
---
--- Here `dir` is just a path and `kind` could be anything from following:
---
--- - `float`
--- - `replace`
--- - `split_above`
--- - `split_above_all`
--- - `split_below`
--- - `split_below_all`
--- - `split_left`
--- - `split_left_most`
--- - `split_right`
--- - `split_right_most`
---
--- Fyler can be used through lua API:
--- >lua
---   local fyler = require("fyler")
---
---   -- Opens finder view with given options
---   fyler.open({ dir = "...", kind = "..." })
---
---   -- Toggles finder view with given options
---   fyler.toggle({ dir = "...", kind = "..." })
---
---   -- Focuses finder view
---   fyler.focus()
---
---   -- Focuses given file path or alternate buffer
---   fyler.navigate("...")
--- <
---
---@tag fyler.nvim

local M = {}

local did_setup = false

---@param opts FylerSetup|nil
function M.setup(opts)
  if vim.fn.has "nvim-0.11" ~= 1 then
    return vim.notify "Fyler requires at least NVIM 0.11"
  end

  if did_setup then
    return
  end

  require("fyler.config").setup(opts)

  did_setup = true

  local finder = require "fyler.views.finder"

  -- Fyler.API: Opens finder view with provided options
  M.open = vim.schedule_wrap(function(args)
    args = args or {}
    finder.open(args.dir, args.kind)
  end)

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
  M.navigate = function(path)
    finder.navigate(path)
  end
end

return M
