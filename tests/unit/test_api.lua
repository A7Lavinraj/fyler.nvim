local util = require "tests.util"

local nv = util.new_neovim()

local T = util.new_test_set {
  hooks = {
    pre_case = function()
      nv.setup()
      nv.mload "fyler"
    end,
    post_case = nv.stop,
  },
}

T["With WinKind"] = util.new_test_set {
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
}

T["With WinKind"]["Open"] = function(kind)
  util.tmp_ctx(function(path)
    nv.cmd(string.format([[lua require('fyler').open({ dir = '%s', kind = '%s' })]], path, kind))
    nv.wait(20)
    nv.expect_screenshot()
  end)
end

T["With WinKind"]["Toggle"] = function(kind)
  util.tmp_ctx(function(path)
    nv.cmd(string.format([[lua require('fyler').toggle({ dir = '%s', kind = '%s' })]], path, kind))
    nv.wait(20)
    nv.expect_screenshot()
    nv.cmd(string.format([[lua require('fyler').toggle({ dir = '%s', kind = '%s' })]], path, kind))
    nv.wait(20)
    nv.expect_screenshot()
  end)
end

T["With WinKind"]["Navigate"] = function(kind)
  util.tmp_ctx(function(path)
    nv.cmd(string.format([[lua require('fyler').open({ dir = '%s', kind = '%s' })]], path, kind))
    nv.wait(20)
    nv.cmd(string.format([[lua require('fyler').navigate('%s')]], vim.fs.joinpath(path, "a-dir", "aa-dir", "aa-file")))
    nv.wait(20)
    nv.expect_screenshot()
  end)
end

return T
