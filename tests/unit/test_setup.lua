local MiniTest = require "mini.test"
local util = require "tests.util"

local eq = MiniTest.expect.equality
local child = util.new_child_neovim()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.setup()
      child.load("fyler", {})

      child.o.laststatus = 3
      child.o.showtabline = 0
      child.o.cmdheight = 0
    end,
    post_case = child.stop,
  },
}

T["configuration"] = function()
  local expect_config = function(field, value)
    eq(child.lua_get([[require('fyler.config').values.]] .. field), value)
  end

  expect_config("hooks.on_delete", vim.NIL)
  expect_config("hooks.on_rename", vim.NIL)
  expect_config("hooks.on_highlight", vim.NIL)

  expect_config("integrations.icon", "mini_icons")

  expect_config("views.finder.close_on_select", true)
  expect_config("views.finder.confirm_simple", false)
  expect_config("views.finder.default_explorer", false)
  expect_config("views.finder.delete_to_trash", false)
  expect_config("views.finder.follow_current_file", true)

  expect_config("views.finder.git_status.enabled", true)
  expect_config("views.finder.git_status.symbols.Untracked", "?")
  expect_config("views.finder.git_status.symbols.Added", "+")
  expect_config("views.finder.git_status.symbols.Modified", "*")
  expect_config("views.finder.git_status.symbols.Deleted", "x")
  expect_config("views.finder.git_status.symbols.Renamed", ">")
  expect_config("views.finder.git_status.symbols.Copied", "~")
  expect_config("views.finder.git_status.symbols.Conflict", "!")
  expect_config("views.finder.git_status.symbols.Ignored", "#")

  expect_config("views.finder.icon.directory_collapsed", vim.NIL)
  expect_config("views.finder.icon.directory_empty", vim.NIL)
  expect_config("views.finder.icon.directory_expanded", vim.NIL)

  expect_config("views.finder.indentscope.enabled", true)
  expect_config("views.finder.indentscope.group", "FylerIndentMarker")
  expect_config("views.finder.indentscope.marker", "│")

  expect_config("views.finder.mappings['q']", "CloseView")
  expect_config("views.finder.mappings['<CR>']", "Select")
  expect_config("views.finder.mappings['<C-t>']", "SelectTab")
  expect_config("views.finder.mappings['|']", "SelectVSplit")
  expect_config("views.finder.mappings['-']", "SelectSplit")
  expect_config("views.finder.mappings['^']", "GotoParent")
  expect_config("views.finder.mappings['=']", "GotoCwd")
  expect_config("views.finder.mappings['.']", "GotoNode")
  expect_config("views.finder.mappings['#']", "CollapseAll")
  expect_config("views.finder.mappings['<BS>']", "CollapseNode")

  expect_config("views.finder.mappings_opts.nowait", false)
  expect_config("views.finder.mappings_opts.noremap", true)
  expect_config("views.finder.mappings_opts.silent", true)

  expect_config("views.finder.watcher.enabled", false)

  expect_config("views.finder.win.border", vim.o.winborder == "" and "single" or vim.o.winborder)

  expect_config("views.finder.win.buf_opts.filetype", "fyler")
  expect_config("views.finder.win.buf_opts.syntax", "fyler")
  expect_config("views.finder.win.buf_opts.buflisted", false)
  expect_config("views.finder.win.buf_opts.buftype", "acwrite")
  expect_config("views.finder.win.buf_opts.expandtab", true)
  expect_config("views.finder.win.buf_opts.shiftwidth", 2)

  expect_config("views.finder.win.kinds.float.height", "70%")
  expect_config("views.finder.win.kinds.float.width", "70%")
  expect_config("views.finder.win.kinds.float.top", "10%")
  expect_config("views.finder.win.kinds.float.left", "15%")

  expect_config("views.finder.win.kinds.split_above.height", "70%")

  expect_config("views.finder.win.kinds.split_above_all.height", "70%")
  expect_config("views.finder.win.kinds.split_above_all.win_opts.winfixheight", true)

  expect_config("views.finder.win.kinds.split_below.height", "70%")

  expect_config("views.finder.win.kinds.split_below_all.height", "70%")
  expect_config("views.finder.win.kinds.split_below_all.win_opts.winfixheight", true)

  expect_config("views.finder.win.kinds.split_left.width", "30%")

  expect_config("views.finder.win.kinds.split_left_most.width", "30%")
  expect_config("views.finder.win.kinds.split_left_most.win_opts.winfixwidth", true)

  expect_config("views.finder.win.kinds.split_right.width", "30%")

  expect_config("views.finder.win.kinds.split_right_most.width", "30%")
  expect_config("views.finder.win.kinds.split_right_most.win_opts.winfixwidth", true)

  expect_config("views.finder.win.win_opts.concealcursor", "nvic")
  expect_config("views.finder.win.win_opts.conceallevel", 3)
  expect_config("views.finder.win.win_opts.cursorline", false)
  expect_config("views.finder.win.win_opts.number", false)
  expect_config("views.finder.win.win_opts.relativenumber", false)
  expect_config("views.finder.win.win_opts.winhighlight", "Normal:FylerNormal,NormalNC:FylerNormalNC")
  expect_config("views.finder.win.win_opts.wrap", false)
  expect_config("views.finder.win.win_opts.signcolumn", "no")
end

return T
