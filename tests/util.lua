local MiniTest = require "mini.test"

local M = {}

---@param name "repo"|"data"
function M.get_dir(name)
  return vim.fs.joinpath(vim.env.FYLER_TEMP_DIR or vim.fs.joinpath(vim.uv.cwd(), ".temp"), name)
end

function M.new_child_neovim()
  local child = MiniTest.new_child_neovim()

  child.setup = function()
    child.restart { "-u", "tests/minit.lua" }
    child.bo.readonly = true
  end

  child.load = function(name, config)
    child.lua(([[require('%s').setup(...)]]):format(name), { config })
  end

  child.set_size = function(lines, columns)
    if type(lines) == "number" then
      child.o.lines = lines
    end

    if type(columns) == "number" then
      child.o.columns = columns
    end
  end

  child.set_lines = function(...)
    child.api.nvim_buf_set_lines(...)
  end

  child.get_lines = function(...)
    return child.api.nvim_buf_get_lines(...)
  end

  child.dbg_screen = function()
    local process_screen = function(arr_2d)
      local n_lines, n_cols = #arr_2d, #arr_2d[1]
      local n_digits = math.floor(math.log10(n_lines)) + 1
      local format = string.format("%%0%dd|%%s", n_digits)
      local lines = {}
      for i = 1, n_lines do
        table.insert(lines, string.format(format, i, table.concat(arr_2d[i])))
      end

      local prefix = string.rep("-", n_digits) .. "|"
      local ruler = prefix .. ("---------|"):rep(math.ceil(0.1 * n_cols)):sub(1, n_cols)
      return string.format("%s\n%s", ruler, table.concat(lines, "\n"))
    end

    if vim.env.DEBUG then
      vim.print(string.format("\n%s\n", process_screen(child.get_screenshot().text)))
    end
  end

  return child
end

return M
