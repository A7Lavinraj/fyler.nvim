require("mini.test").run({
  execute = { stop_on_error = true },
  collect = {
    find_files = function() return vim.fn.globpath("tests", "**/test_*.lua", true, true) end,
    filter_cases = vim.env.FILTER and function(case)
      local desc = vim.deepcopy(case.desc)
      table.remove(desc, 1)
      desc[#desc + 1] = vim.inspect(case.args, { newline = "", indent = "" })
      return table.concat(desc, " "):match(vim.env.FILTER)
    end,
  },
})
