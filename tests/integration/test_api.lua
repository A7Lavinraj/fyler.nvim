local MiniTest = require "mini.test"
local util = require "tests.util"

local child = util.new_child_neovim()

local eq = MiniTest.expect.equality

local dir_data = util.get_dir "data"

---@param str string
---@return string
local function parse_name(str)
  local name = string.match(str, "/%d+%s(.*)$")
  return name
end

local T = MiniTest.new_set {
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
  hooks = {
    pre_case = function()
      child.setup()
      child.set_size(18, 70)
      child.load("fyler", {
        integrations = { icon = "none" },
        views = { finder = { git_status = { enabled = false } } },
      })

      child.o.laststatus = 3
      child.o.showtabline = 0
      child.o.cmdheight = 0

      vim.fn.mkdir(dir_data)
      vim.fn.mkdir(vim.fs.joinpath(dir_data, "test-dir"))
      vim.fn.writefile({ "test-deep-file content" }, vim.fs.joinpath(dir_data, "test-dir", "test-deep-file"), "a")
      vim.fn.writefile({ "test-file content" }, vim.fs.joinpath(dir_data, "test-file"), "a")
    end,
    post_case = function()
      child.stop()

      vim.fn.delete(dir_data, "rf")
    end,
  },
}

T["open"] = function(kind)
  child.cmd(string.format([[ lua require('fyler').open { dir = '%s', kind = '%s' } ]], dir_data, kind))

  vim.uv.sleep(20)

  eq(child.o.filetype, "fyler")

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")

  child.type_keys "q"

  eq(child.o.filetype, "")
end

T["toggle"] = function(kind)
  child.cmd(string.format([[ lua require('fyler').toggle { dir = '%s', kind = '%s' } ]], dir_data, kind))

  vim.uv.sleep(20)

  eq(child.o.filetype, "fyler")

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")

  child.cmd(string.format([[ lua require('fyler').toggle { dir = '%s', kind = '%s' } ]], dir_data, kind))

  eq(child.o.filetype, "")
end

T["close"] = function(kind)
  child.cmd(string.format([[ lua require('fyler').toggle { dir = '%s', kind = '%s' } ]], dir_data, kind))

  vim.uv.sleep(20)

  eq(child.o.filetype, "fyler")

  child.cmd [[ lua require('fyler').close() ]]

  eq(child.o.filetype, "")
end

T["navigate"] = function(kind)
  child.cmd(string.format([[ lua require('fyler').open { dir = '%s', kind = '%s' } ]], dir_data, kind))

  vim.uv.sleep(20)

  child.cmd(
    string.format([[ lua require('fyler').navigate '%s' ]], vim.fs.joinpath(dir_data, "test-dir/test-deep-file"))
  )

  vim.uv.sleep(20)

  eq(child.api.nvim_get_current_line():match "/%d+%s(.*)$", "test-deep-file")
end

return T
