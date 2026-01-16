vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.getcwd(), ".temp", "deps", "mini.doc"))

local minidoc = require("mini.doc")

minidoc.setup()

minidoc.generate(
  {
    "lua/fyler.lua",
    "lua/fyler/config.lua",
  },
  "doc/fyler.txt",
  {
    hooks = {
      file = function() end,
      sections = {
        ["@signature"] = function(s) s:remove() end,
        ["@return"] = function(s) s.parent:clear_lines() end,
        ["@alias"] = function(s) s.parent:clear_lines() end,
        ["@class"] = function(s) s.parent:clear_lines() end,
        ["@param"] = function(s) s.parent:clear_lines() end,
      },
    },
  }
)
