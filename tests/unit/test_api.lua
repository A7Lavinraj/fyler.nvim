local helper = require("tests.helper")

local nvim = helper.new_neovim()
local equal = helper.equal
local match_pattern = helper.match_pattern

local function make_tree(children)
  local temp_dir = vim.fs.joinpath(_G.FYLER_TEMP_DIR, "data")
  vim.fn.mkdir(temp_dir, "p")

  require("mini.test").finally(function() vim.fn.delete(temp_dir, "rf") end)

  for _, path in ipairs(children) do
    local path_ext = temp_dir .. "/" .. path
    if vim.endswith(path, "/") then
      vim.fn.mkdir(path_ext)
    else
      vim.fn.writefile({}, path_ext)
    end
  end

  return temp_dir
end

local T = helper.new_set({
  hooks = {
    pre_case = function() nvim.setup({ views = { finder = { columns_order = {} } } }) end,
    post_case_once = nvim.stop,
  },
})

T["Each WinKind Can"] = helper.new_set({
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
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.setup({ views = { finder = { win = { kind = kind }, columns_order = {} } } })
  nvim.fn.chdir(path)
  nvim.forward_lua("require('fyler').open")()
  vim.uv.sleep(20)
  nvim.expect_screenshot()
end

T["Each WinKind Can"]["Open With Arguments"] = function(kind)
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.expect_screenshot()
end

T["Each WinKind Can"]["Open And Handles Sudden Undo"] = function(kind)
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.type_keys("u")
  equal(#nvim.get_lines(0, 0, -1, false) > 1, true)
  equal(nvim.cmd_capture("1messages"), "Already at oldest change")
end

T["Each WinKind Can"]["Open And Jump To Current File"] = function(kind)
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.cmd("edit " .. vim.fs.joinpath(path, "b-file"))
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  match_pattern(nvim.api.nvim_get_current_line(), "b-file")
end

T["Each WinKind Can"]["Toggle With Arguments"] = function(kind)
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.forward_lua("require('fyler').toggle")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.forward_lua("require('fyler').toggle")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.expect_screenshot()
end

T["Each WinKind Can"]["Navigate"] = function(kind)
  local path = make_tree({ "a-file", "b-file", "a-dir/", "b-dir/" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.forward_lua("require('fyler').navigate")(
    vim.fn.fnamemodify(vim.fs.joinpath(path, "a-dir", "aa-dir", "aaa-file"), ":p")
  )
  vim.uv.sleep(20)
  nvim.expect_screenshot()
end

return T
