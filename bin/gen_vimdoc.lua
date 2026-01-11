local M = dofile("bin/setup_deps.lua")

vim.opt.runtimepath:prepend(".")
vim.opt.runtimepath:prepend(vim.fs.joinpath(M.get_dir("repo"), "mini.doc"))

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
