local MiniTest = require("mini.test")

local M = {}

M.equal = MiniTest.expect.equality
M.match_pattern = MiniTest.new_expectation(
  "string matching",
  function(str, pattern) return str:find(pattern) ~= nil end,
  function(str, pattern) return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str) end
)

function M.make_mock_dir()
  local temp_dir = vim.fs.joinpath(_G.FYLER_TEMP_DIR, "data")
  MiniTest.finally(function() vim.fn.delete(temp_dir, "rf") end)

  for _, path in ipairs({
    "A-file-1",
    "a-file",
    "b-file",
    "a-dir/aa-dir/aaa-file",
    "b-dir/ba-file",
  }) do
    local path_ext = vim.fs.joinpath(temp_dir, path)

    vim.fn.mkdir(vim.fn.fnamemodify(path_ext, ":h"), "p")

    if vim.endswith(path_ext, "/") then
      vim.fn.mkdir(path_ext)
    else
      vim.fn.writefile({}, path_ext)
    end
  end

  return temp_dir
end

M.new_set = MiniTest.new_set

function M.new_neovim()
  local nvim = MiniTest.new_child_neovim()

  nvim.setup = function(opts)
    nvim.restart({
      "-u",
      "tests/minimal_init.lua",
      "-c",
      string.format("lua require('fyler').setup(%s)", vim.inspect(opts or {})),
    })
    nvim.set_size(20, 80)
  end

  nvim.set_size = function(lines, columns)
    if type(lines) == "number" then nvim.o.lines = lines end

    if type(columns) == "number" then nvim.o.columns = columns end
  end

  nvim.set_lines = function(...) nvim.api.nvim_buf_set_lines(...) end

  nvim.get_lines = function(...) return nvim.api.nvim_buf_get_lines(...) end

  nvim.forward_lua = function(fun_str)
    local lua_cmd = fun_str .. "(...)"
    return function(...) return nvim.lua_get(lua_cmd, { ... }) end
  end

  nvim.module_load = function(name, config)
    local lua_cmd = ([[require('%s').setup(...)]]):format(name)
    nvim.lua(lua_cmd, { config })
  end

  nvim.module_unload = function(name)
    nvim.lua(([[package.loaded['%s'] = nil]]):format(name))
    if nvim.fn.exists("#" .. name) == 1 then nvim.api.nvim_del_augroup_by_name(name) end
  end

  nvim.expect_screenshot = function(opts, path)
    opts = opts or {}
    local screenshot_opts = { redraw = opts.redraw }
    opts.redraw = nil
    MiniTest.expect.reference_screenshot(nvim.get_screenshot(screenshot_opts), path, opts)
  end

  nvim.validate_tree = function(dir, ref_tree)
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
    M.equal(tree, ref)
  end

  nvim.dbg_screen = function()
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

      vim.print(string.format("\n%s\n", process_screen(nvim.get_screenshot().text)))
    end
  end

  return nvim
end

return M
