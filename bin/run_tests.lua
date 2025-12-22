local get_dir = dofile("bin/setup_deps.lua").get_dir
vim.opt.runtimepath:prepend "."
vim.opt.runtimepath:prepend(vim.fs.joinpath(get_dir "repo", "mini.test"))

local filter = vim.env.FILTER
require("mini.test").run {
  collect = {
    find_files = function()
      return vim.fn.globpath("tests", "**/test_*.lua", true, true)
    end,
    filter_cases = filter and function(case)
      local desc = vim.deepcopy(case.desc)
      table.remove(desc, 1)
      local args = vim.inspect(case.args, { newline = "", indent = "" })
      desc[#desc + 1] = args
      return table.concat(desc, " "):match(filter)
    end or nil,
  },
}
