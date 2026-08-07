local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })

local eq = helper.expect.equality

local is_finder_active = function()
  return n.lua_get([[(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'fyler_finder' then return true end
    end
    return false
  end)()]])
end

T['Default explorer'] = helper.new_set()

T['Default explorer']['is opened on directory edit'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.cmd('edit ' .. tmpdir)
  eq(is_finder_active(), true)
end

T['Default explorer']['is opened only for the current buffer'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.lua(('vim.cmd("edit %s"); vim.cmd("enew")'):format(tmpdir))
  eq(is_finder_active(), false)
  n.cmd('bprev')
  eq(is_finder_active(), true)
end

T['Default explorer']['is not opened during diff-mode'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.wo.diff = true
  n.cmd('edit ' .. tmpdir)
  eq(is_finder_active(), false)
end

return T
