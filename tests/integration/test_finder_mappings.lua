local helper = require("tests.helper")

local nvim = helper.new_neovim()

local function make_tree(children)
  local temp_dir = vim.fs.joinpath(_G.FYLER_TEMP_DIR, "data")
  vim.fn.mkdir(temp_dir, "p")

  require("mini.test").finally(function() vim.fn.delete(temp_dir, "rf") end)

  for _, path in ipairs(children) do
    local path_ext = temp_dir .. "/" .. path
    if vim.endswith(path, "/") then
      vim.fn.mkdir(path_ext)
    else
      vim.fn.writefile({ "---FILE CONTENT---" }, path_ext)
    end
  end

  return temp_dir
end

local T = helper.new_set({
  hooks = {
    pre_case = function() nvim.setup({ views = { finder = { columns_order = {} } } }) end,
    post_case = nvim.stop,
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

T["Each WinKind Can"]["Handle Default Mappings"] = function(kind)
  local path = make_tree({
    "a-file",
    "a-dir/",
    "a-dir/aa-dir/",
    "a-dir/aa-dir/aa-file",
    "a-dir/aa-dir/aab-dir/",
    "a-dir/aa-dir/aab-dir/aab-file",
  })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.type_keys(".")
  vim.uv.sleep(20)
  nvim.type_keys(".")
  vim.uv.sleep(20)
  nvim.type_keys("<CR>")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.type_keys("j<BS>")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.type_keys("^")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.type_keys("=")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.type_keys("#")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  nvim.type_keys("q")
  nvim.expect_screenshot()

  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.type_keys("G-")
  nvim.expect_screenshot()
  nvim.cmd("quit")
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.type_keys("G|")
  nvim.expect_screenshot()
  nvim.cmd("quit")
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.type_keys("G<C-t>")
  nvim.expect_screenshot()
end

return T
