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
      child.load("fyler", {})

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

T["Select"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "<Enter>"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-deep-file")
  eq(parse_name(lines[3]), "test-file")

  child.type_keys "<Enter>"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)
  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["SelectSplit"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G-"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["SelectVSplit"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G|"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["SelectTab"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G<C-t>"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["GotoParent"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], vim.fs.joinpath(dir_data, "test-dir"), kind))

  vim.uv.sleep(20)

  child.type_keys "^"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["GotoCwd"] = function(kind)
  -- NOTE: For some reason if doing cd first then fyler will not open
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "."
  vim.uv.sleep(20)

  child.type_keys "="
  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["GotoNode"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "."

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-deep-file")
end

T["CollapseAll"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "<Enter>"

  vim.uv.sleep(20)

  child.type_keys "j<Bs>"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)
  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["CollapseNode"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "<Enter>"

  vim.uv.sleep(20)

  child.type_keys "j<Bs>"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)
  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

return T
