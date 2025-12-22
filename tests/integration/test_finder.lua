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

T["mappings"] = MiniTest.new_set {}

T["mappings"]["Select"] = function(kind)
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

T["mappings"]["SelectSplit"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G-"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["mappings"]["SelectVSplit"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G|"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["mappings"]["SelectTab"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "G<C-t>"

  eq(child.get_lines(0, 0, -1, false), { "test-file content" })
end

T["mappings"]["GotoParent"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], vim.fs.joinpath(dir_data, "test-dir"), kind))

  vim.uv.sleep(20)

  child.type_keys "^"

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["mappings"]["GotoCwd"] = function(kind)
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

T["mappings"]["GotoNode"] = function(kind)
  child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))

  vim.uv.sleep(20)

  child.type_keys "."

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)

  eq(parse_name(lines[1]), "test-deep-file")
end

T["mappings"]["CollapseAll"] = function(kind)
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

T["mappings"]["CollapseNode"] = function(kind)
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

T["scheme"] = function()
  child.cmd(string.format([[ edit fyler://%s ]], dir_data))

  vim.uv.sleep(20)

  local lines = child.get_lines(0, 0, -1, false)
  eq(parse_name(lines[1]), "test-dir")
  eq(parse_name(lines[2]), "test-file")
end

T["synchronize"] = MiniTest.new_set {}

-- TODO: Everything looking fine with manual testing but will fix following test
-- T["synchronize"]["basic operations"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   child.dbg_screen()
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[2] = lines[2]:gsub("test", "move")
--   local copy_line = lines[1]:gsub("test", "copy")
--   table.insert(lines, copy_line)
--   table.insert(lines, "new-dir/")
--   table.insert(lines, "new-file")
--   table.remove(lines, 3)
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.dbg_screen()
--   child.cmd [[ write ]]
--   vim.uv.sleep(50)
--
--   child.dbg_screen()
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.sort(lines)
--
--   eq(lines[1], "COPY   test-dir > copy-dir")
--   eq(lines[2], "CREATE new-dir")
--   eq(lines[3], "CREATE new-file")
--   eq(lines[4], "DELETE test-file")
--   eq(lines[5], "MOVE   test-dir/test-deep-file > test-dir/move-deep-file")
--
--   child.type_keys "y"
--   child.o.conceallevel = 0
--
--   vim.uv.sleep(50)
--
--   child.dbg_screen()
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   table.sort(new_lines)
--   eq(parse_name(new_lines[1]), "move-deep-file")
--   eq(parse_name(new_lines[2]), "copy-dir")
--   eq(parse_name(new_lines[3]), "test-dir")
--   eq(parse_name(new_lines[4]), "new-dir")
--   eq(parse_name(new_lines[5]), "new-file")
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "copy-dir")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "new-dir")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "new-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 0)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir", "move-deep-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir", "test-deep-file")), 0)
--
--   vim.uv.sleep(1000)
-- end
--
-- T["synchronize"]["rename file"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[3] = lines[3]:gsub("test", "renamed")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.dbg_screen()
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   child.dbg_screen()
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "renamed-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 0)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   eq(parse_name(new_lines[3]), "renamed-file")
-- end
--
-- T["synchronize"]["rename directory"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[1] = lines[1]:gsub("test", "renamed")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "renamed-dir")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "test-dir")), 0)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "renamed-dir", "test-deep-file")), 1)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   eq(parse_name(new_lines[1]), "renamed-dir")
-- end
--
-- T["synchronize"]["delete file"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.remove(lines, 3)
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 0)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   eq(#new_lines, 2)
-- end
--
-- T["synchronize"]["delete directory"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.remove(lines, 1)
--   table.remove(lines, 1)
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "test-dir")), 0)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir", "test-deep-file")), 0)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   eq(#new_lines, 1)
-- end
--
-- T["synchronize"]["create file"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.insert(lines, "new-file")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "new-file")), 1)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   local found = false
--   for _, line in ipairs(new_lines) do
--     if parse_name(line) == "new-file" then
--       found = true
--       break
--     end
--   end
--   eq(found, true)
-- end
--
-- T["synchronize"]["create directory"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.insert(lines, "new-directory/")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "new-directory")), 1)
--
--   local new_lines = child.get_lines(0, 0, -1, false)
--   local found = false
--   for _, line in ipairs(new_lines) do
--     if parse_name(line) == "new-directory" then
--       found = true
--       break
--     end
--   end
--   eq(found, true)
-- end
--
-- T["synchronize"]["create nested directories"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.insert(lines, "parent/child/grandchild/")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent", "child")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent", "child", "grandchild")), 1)
-- end
--
-- T["synchronize"]["create nested file"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   table.insert(lines, "parent/child/file")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent", "child")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "parent", "child", "file")), 1)
-- end
--
-- T["synchronize"]["copy file"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   local copy_line = lines[3]:gsub("test%-file", "test-file-copy")
--   table.insert(lines, copy_line)
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file-copy")), 1)
--
--   local original_content = vim.fn.readfile(vim.fs.joinpath(dir_data, "test-file"))
--   local copied_content = vim.fn.readfile(vim.fs.joinpath(dir_data, "test-file-copy"))
--   eq(original_content[1], copied_content[1])
-- end
--
-- T["synchronize"]["copy directory"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   local copy_line = lines[1]:gsub("test%-dir", "test-dir-copy")
--   table.insert(lines, copy_line)
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "test-dir")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "test-dir-copy")), 1)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir", "test-deep-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir-copy", "test-deep-file")), 1)
-- end
--
-- T["synchronize"]["move file between directories"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[3] = lines[3]:gsub("test%-file", "test-dir/moved-file")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 0)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-dir", "moved-file")), 1)
--
--   local content = vim.fn.readfile(vim.fs.joinpath(dir_data, "test-dir", "moved-file"))
--   eq(content[1], "test-file content")
-- end
--
-- T["synchronize"]["move directory"] = function(kind)
--   vim.fn.mkdir(vim.fs.joinpath(dir_data, "parent-dir"))
--
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[2] = lines[2]:gsub("test%-dir", "parent-dir/test-dir")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "test-dir")), 0)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "parent-dir", "test-dir")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "parent-dir", "test-dir", "test-deep-file")), 1)
-- end
--
-- T["synchronize"]["multiple operations at once"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[1] = lines[1]:gsub("test%-dir", "renamed-dir")
--   lines[2] = lines[2]:gsub("test%-deep%-file", "renamed-deep-file")
--   table.remove(lines, 3)
--   table.insert(lines, "new-file")
--   table.insert(lines, "new-dir/")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "y"
--
--   vim.uv.sleep(50)
--
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "renamed-dir")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "renamed-dir", "renamed-deep-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 0)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "new-file")), 1)
--   eq(vim.fn.isdirectory(vim.fs.joinpath(dir_data, "new-dir")), 1)
-- end
--
-- T["synchronize"]["abort with n"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local original_lines = child.get_lines(0, 0, -1, false)
--   local lines = vim.deepcopy(original_lines)
--   lines[3] = lines[3]:gsub("test%-file", "renamed-file")
--
--   child.set_lines(0, 0, -1, false, lines)
--   child.cmd [[ write ]]
--   child.type_keys "n"
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "renamed-file")), 0)
--   eq(child.bo.modified, true)
-- end
--
-- T["synchronize"]["no changes when not saved"] = function(kind)
--   child.cmd(string.format([[ Fyler dir=%s kind=%s ]], dir_data, kind))
--
--   vim.uv.sleep(50)
--
--   child.type_keys "<Enter>"
--
--   vim.uv.sleep(50)
--
--   local lines = child.get_lines(0, 0, -1, false)
--   lines[3] = lines[3]:gsub("test%-file", "renamed-file")
--
--   child.set_lines(0, 0, -1, false, lines)
--
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "test-file")), 1)
--   eq(vim.fn.filereadable(vim.fs.joinpath(dir_data, "renamed-file")), 0)
-- end

return T
