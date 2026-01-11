local MiniTest = require("mini.test")

local M = {}

M.eq = MiniTest.expect.equality
M.mp = MiniTest.new_expectation(
  "string matching",
  function(str, pattern) return str:find(pattern) ~= nil end,
  function(str, pattern) return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str) end
)

---@param fn fun(path: string)
function M.tmp_ctx(fn)
  local function item_config(name, type, children) return { name = name, type = type, children = children } end

  local fake_data = {
    item_config("a-dir", "directory", {
      item_config("aa-dir", "directory", {
        item_config("aaa-file"),
      }),
      item_config("aa-file", "file"),
      item_config("ab-file", "file"),
    }),
    item_config("b-dir", "file", {
      item_config("ba-file", "file"),
    }),
    item_config("a-file", "file"),
    item_config("A-file-2", "file"),
    item_config("b-file", "file"),
  }

  local root = dofile("bin/setup_deps.lua").get_dir("data")

  local function write_file(path)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({}, path)
  end

  local function create_item(base, item)
    local path = vim.fs.joinpath(base, item.name)

    if item.type == "directory" then
      vim.fn.mkdir(path, "p")
      if item.children then
        for _, child in ipairs(item.children) do
          create_item(path, child)
        end
      end
    else
      write_file(path)
    end
  end

  vim.fn.delete(root, "rf")
  vim.fn.mkdir(root, "p")

  for _, item in ipairs(fake_data) do
    create_item(root, item)
  end

  fn(root)
end

M.new_set = MiniTest.new_set

function M.new_neovim()
  local child = MiniTest.new_child_neovim()

  child.setup = function()
    child.restart({ "-u", "tests/minit.lua", "-c", "lua require('fyler').setup()" })
    child.set_size(20, 80)
  end

  child.set_size = function(lines, columns)
    if type(lines) == "number" then child.o.lines = lines end

    if type(columns) == "number" then child.o.columns = columns end
  end

  child.set_lines = function(...) child.api.nvim_buf_set_lines(...) end

  child.get_lines = function(...) return child.api.nvim_buf_get_lines(...) end

  child.wait = vim.uv.sleep

  child.forward_lua = function(fun_str)
    local lua_cmd = fun_str .. "(...)"
    return function(...) return child.lua_get(lua_cmd, { ... }) end
  end

  child.module_load = function(name, config)
    local lua_cmd = ([[require('%s').setup(...)]]):format(name)
    child.lua(lua_cmd, { config })
  end

  child.module_unload = function(name)
    child.lua(([[package.loaded['%s'] = nil]]):format(name))
    child.lua(('_G["%s"] = nil'):format(name))
    if child.fn.exists("#" .. name) == 1 then child.api.nvim_del_augroup_by_name(name) end
  end

  child.expect_screenshot = function(opts, path)
    opts = opts or {}
    local screenshot_opts = { redraw = opts.redraw }
    opts.redraw = nil
    MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path, opts)
  end

  child.dbg_screen = function()
    if vim.env.DEBUG then
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

      vim.print(string.format("\n%s\n", process_screen(child.get_screenshot().text)))
    end
  end

  return child
end

return M
