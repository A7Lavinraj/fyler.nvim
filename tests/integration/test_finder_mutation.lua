local helper = require("tests.helper")

local nvim = helper.new_neovim()
local equal = helper.equal

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

local function check_tree(dir, ref_tree)
  nvim.lua("_G.dir = " .. vim.inspect(dir))
  local tree = nvim.lua([[
    local read_dir
    read_dir = function(path, res)
      res = res or {}
      local fs = vim.loop.fs_scandir(path)
      local name, fs_type = vim.loop.fs_scandir_next(fs)
      while name do
        local cur_path = path .. '/' .. name
        table.insert(res, cur_path .. (fs_type == 'directory' and '/' or ''))
        if fs_type == 'directory' then read_dir(cur_path, res) end
        name, fs_type = vim.loop.fs_scandir_next(fs)
      end
      return res
    end
    local dir_len = _G.dir:len()
    return vim.tbl_map(function(p) return p:sub(dir_len + 2) end, read_dir(_G.dir))
  ]])
  table.sort(tree)
  local ref = vim.deepcopy(ref_tree)
  table.sort(ref)
  equal(tree, ref)
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

T["Each WinKind Can"]["Handle Empty Actions"] = function(kind)
  local path = make_tree({})
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.set_lines(0, -1, -1, false, { "" })
  nvim.expect_screenshot()
  nvim.cmd("write")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
end

T["Each WinKind Can"]["Do Create Actions"] = function(kind)
  local path = make_tree({})
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.set_lines(0, 0, -1, false, { "new-file", "new-dir/" })
  nvim.expect_screenshot()
  nvim.cmd("write")
  nvim.type_keys("y")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  check_tree(path, { "new-file", "new-dir/" })
end

T["Each WinKind Can"]["Do Delete Actions"] = function(kind)
  local path = make_tree({ "a-file", "a-dir/", "b-dir/", "b-dir/ba-file" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  nvim.set_lines(0, 0, -1, false, {})
  nvim.expect_screenshot()
  nvim.cmd("write")
  nvim.type_keys("y")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  check_tree(path, {})
end

T["Each WinKind Can"]["Do Move Actions"] = function(kind)
  local path = make_tree({ "a-file", "a-dir/", "b-dir/", "b-dir/ba-file" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  -- stylua: ignore
  nvim.set_lines(0, 0, -1, false, vim.tbl_map(function(line) return line .. "-renamed" end, nvim.get_lines(0, 0, -1, false)))
  nvim.expect_screenshot()
  nvim.cmd("write")
  nvim.type_keys("y")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  check_tree(path, { "a-file-renamed", "a-dir-renamed/", "b-dir-renamed/", "b-dir-renamed/ba-file" })
end

T["Each WinKind Can"]["Do Copy Actions"] = function(kind)
  local path = make_tree({ "a-file", "a-dir/", "b-dir/", "b-dir/ba-file" })
  nvim.forward_lua("require('fyler').open")({ dir = path, kind = kind })
  vim.uv.sleep(20)
  -- stylua: ignore
  nvim.set_lines(0, -1, -1, false, vim.tbl_map(function(line) return line .. "-copied" end, nvim.get_lines(0, 0, -1, false)))
  nvim.expect_screenshot()
  nvim.cmd("write")
  nvim.type_keys("y")
  vim.uv.sleep(20)
  nvim.expect_screenshot()
  -- stylua: ignore
  check_tree(path, { "a-file", "a-dir/", "b-dir/", "b-dir/ba-file", "a-file-copied", "a-dir-copied/", "b-dir-copied/", "b-dir-copied/ba-file" })
end

-- TODO: Still need to implement compound actions testing but first need to find a way to reproduce the bug

return T
