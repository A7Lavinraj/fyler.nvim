local util = require("tests.util")

local nv = util.new_neovim()
local eq = util.eq
local mp = util.mp

local T = util.new_set({
  hooks = {
    pre_case = nv.setup,
    post_case = nv.stop,
  },
})

T["Each WinKind Can"] = util.new_set({
  parametrize = {
    { "float" },
    { "replace" },
    { "split_left" },
    { "split_left_most" },
    { "split_above" },
    { "split_above_all" },
    { "split_right" },
    { "split_right_most" },
    { "split_below" },
    { "split_below_all" },
  },
})

T["Each WinKind Can"]["Open Without Arguments"] = function(kind)
  util.tmp_ctx(function(path)
    nv.module_unload("fyler")
    nv.module_load("fyler", { views = { finder = { win = { kind = kind } } } })
    nv.fn.chdir(path)
    nv.forward_lua("require('fyler').open")()
    nv.wait(50)
    nv.dbg_screen()
  end)
end

T["Each WinKind Can"]["Open With Arguments"] = function(kind)
  util.tmp_ctx(function(path)
    nv.forward_lua("require('fyler').open")({ dir = path, kind = kind })
    nv.wait(50)
    nv.expect_screenshot()
  end)
end

T["Each WinKind Can"]["Open And Handles Sudden Undo"] = function(kind)
  util.tmp_ctx(function(path)
    nv.forward_lua("require('fyler').open")({ dir = path, kind = kind })
    nv.wait(50)
    nv.type_keys("u")
    eq(#nv.get_lines(0, 0, -1, false) > 1, true)
    eq(nv.cmd_capture("1messages"), "Already at oldest change")
  end)
end

T["Each WinKind Can"]["Open And Jump To Current File"] = function(kind)
  util.tmp_ctx(function(path)
    nv.cmd("edit " .. vim.fs.joinpath(path, "b-file"))
    nv.forward_lua("require('fyler').open")({ dir = path, kind = kind })
    nv.wait(50)
    mp(nv.api.nvim_get_current_line(), "b-file")
  end)
end

T["Each WinKind Can"]["Toggle With Arguments"] = function(kind)
  util.tmp_ctx(function(path)
    nv.forward_lua("require('fyler').toggle")({ dir = path, kind = kind })
    nv.wait(50)
    nv.expect_screenshot()
    nv.forward_lua("require('fyler').toggle")({ dir = path, kind = kind })
    nv.wait(50)
    nv.expect_screenshot()
  end)
end

T["Each WinKind Can"]["Navigate"] = function(kind)
  util.tmp_ctx(function(path)
    nv.forward_lua("require('fyler').open")({ dir = path, kind = kind })
    nv.wait(50)
    nv.forward_lua("require('fyler').navigate")(
      vim.fn.fnamemodify(vim.fs.joinpath(path, "a-dir", "aa-dir", "aaa-file"), ":p")
    )
    nv.wait(50)
    nv.expect_screenshot()
  end)
end

return T
