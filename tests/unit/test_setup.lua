local util = require "tests.util"

local eq = util.eq
local nv = util.new_neovim()

local T = util.new_set {
  hooks = {
    pre_case = nv.setup,
    post_case = nv.stop,
  },
}

T["Side Effects"] = function()
  local validate_hl_group = function(name, ref)
    util.mt(nv.cmd_capture("hi " .. name), ref)
  end

  eq(nv.fn.hlexists "FylerBlue", 1)
  eq(nv.fn.hlexists "FylerGreen", 1)
  eq(nv.fn.hlexists "FylerGrey", 1)
  eq(nv.fn.hlexists "FylerRed", 1)
  eq(nv.fn.hlexists "FylerYellow", 1)

  eq(nv.fn.hlexists "FylerFSDirectoryIcon", 1)
  eq(nv.fn.hlexists "FylerFSDirectoryName", 1)

  eq(nv.fn.hlexists "FylerFSFile", 1)
  eq(nv.fn.hlexists "FylerFSLink", 1)

  eq(nv.fn.hlexists "FylerGitAdded", 1)
  eq(nv.fn.hlexists "FylerGitConflict", 1)
  eq(nv.fn.hlexists "FylerGitDeleted", 1)
  eq(nv.fn.hlexists "FylerGitIgnored", 1)
  eq(nv.fn.hlexists "FylerGitModified", 1)
  eq(nv.fn.hlexists "FylerGitRenamed", 1)
  eq(nv.fn.hlexists "FylerGitStaged", 1)
  eq(nv.fn.hlexists "FylerGitUnstaged", 1)
  eq(nv.fn.hlexists "FylerGitUntracked", 1)

  eq(nv.fn.hlexists "FylerWinPick", 1)

  validate_hl_group("FylerNormal", "links to Normal")
  validate_hl_group("FylerNormalNC", "links to NormalNC")
  validate_hl_group("FylerBorder", "links to FylerNormal")
  validate_hl_group("FylerIndentMarker", "links to FylerGrey")
  validate_hl_group("FylerDiagnosticError", "links to DiagnosticError")
  validate_hl_group("FylerDiagnosticWarn", "links to DiagnosticWarn")
  validate_hl_group("FylerDiagnosticInfo", "links to DiagnosticInfo")
  validate_hl_group("FylerDiagnosticHint", "links to DiagnosticHint")
end

T["Setup Config"] = function()
  local expect_config = function(field, value)
    eq(nv.lua_get([[require('fyler.config').values.]] .. field), value)
  end

  expect_config("hooks.on_delete", vim.NIL)
  expect_config("hooks.on_rename", vim.NIL)
  expect_config("hooks.on_highlight", vim.NIL)

  expect_config("integrations.icon", "mini_icons")
  expect_config("integrations.winpick", "none")

  expect_config("views.finder.close_on_select", true)
  expect_config("views.finder.confirm_simple", false)
  expect_config("views.finder.default_explorer", false)
  expect_config("views.finder.delete_to_trash", false)
  expect_config("views.finder.columns_order", { "git", "diagnostic" })

  expect_config("views.finder.columns.git.enabled", true)
  expect_config("views.finder.columns.git.symbols.Untracked", "?")
  expect_config("views.finder.columns.git.symbols.Added", "A")
  expect_config("views.finder.columns.git.symbols.Modified", "M")
  expect_config("views.finder.columns.git.symbols.Deleted", "D")
  expect_config("views.finder.columns.git.symbols.Renamed", "R")
  expect_config("views.finder.columns.git.symbols.Copied", "C")
  expect_config("views.finder.columns.git.symbols.Conflict", "!")
  expect_config("views.finder.columns.git.symbols.Ignored", " ")

  expect_config("views.finder.columns.diagnostic.enabled", true)
  expect_config("views.finder.columns.diagnostic.symbols.Error", "E")
  expect_config("views.finder.columns.diagnostic.symbols.Warn", "W")
  expect_config("views.finder.columns.diagnostic.symbols.Info", "I")
  expect_config("views.finder.columns.diagnostic.symbols.Hint", "H")

  expect_config("views.finder.icon.directory_collapsed", vim.NIL)
  expect_config("views.finder.icon.directory_empty", vim.NIL)
  expect_config("views.finder.icon.directory_expanded", vim.NIL)

  expect_config("views.finder.indentscope.enabled", true)
  expect_config("views.finder.indentscope.markers[1][1]", "│")
  expect_config("views.finder.indentscope.markers[1][2]", "FylerIndentMarker")
  expect_config("views.finder.indentscope.markers[2][1]", "└")
  expect_config("views.finder.indentscope.markers[2][2]", "FylerIndentMarker")

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

  expect_config("views.finder.follow_current_file", true)

  expect_config("views.finder.watcher.enabled", false)

  expect_config("views.finder.win.border", "single")

  expect_config("views.finder.win.buf_opts.bufhidden", "hide")
  expect_config("views.finder.win.buf_opts.buflisted", false)
  expect_config("views.finder.win.buf_opts.buftype", "acwrite")
  expect_config("views.finder.win.buf_opts.expandtab", true)
  expect_config("views.finder.win.buf_opts.filetype", "fyler")
  expect_config("views.finder.win.buf_opts.shiftwidth", 2)
  expect_config("views.finder.win.buf_opts.syntax", "fyler")
  expect_config("views.finder.win.buf_opts.swapfile", false)

  expect_config("views.finder.win.kind", "replace")

  expect_config("views.finder.win.kinds.float.height", "70%")
  expect_config("views.finder.win.kinds.float.width", "70%")
  expect_config("views.finder.win.kinds.float.top", "10%")
  expect_config("views.finder.win.kinds.float.left", "15%")

  expect_config("views.finder.win.kinds.split_above.height", "70%")

  expect_config("views.finder.win.kinds.split_above_all.height", "70%")

  expect_config("views.finder.win.kinds.split_above_all.win_opts.winfixheight", true)

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
  expect_config("views.finder.win.win_opts.signcolumn", "no")
  expect_config("views.finder.win.win_opts.winhighlight", "Normal:FylerNormal,NormalNC:FylerNormalNC")
  expect_config("views.finder.win.win_opts.wrap", false)
end

return T
