local a = require("fyler.lib.async")
local algos = require("fyler.views.explorer.algos")
local config = require("fyler.config")
local confirm_view = require("fyler.views.confirm")
local fs = require("fyler.lib.fs")
local git = require("fyler.lib.git")
local store = require("fyler.views.explorer.store")
local ui = require("fyler.views.explorer.ui")
local util = require("fyler.lib.util")

local M = {}

local fn = vim.fn
local api = vim.api

local async = a.async
local awaited_queue = a.awaited_queue.new()
local await_schedule = a.util.await_schedule

---@param view table
function M.n_close_view(view)
  return function() view.win:hide() end
end

---@param view FylerExplorerView
function M.n_select(view)
  return function()
    local itemid = algos.match_itemid(api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    if entry:is_dir() then
      view.root:find(itemid):toggle()
      api.nvim_exec_autocmds("User", { pattern = "RefreshView" })
    else
      if util.is_valid_winid(view.win.old_winid) then
        if config.values.views.explorer.close_on_select then view.win:hide() end

        api.nvim_set_current_win(view.win.old_winid)
        api.nvim_win_call(view.win.old_winid, function() vim.cmd.edit(entry:get_path()) end)
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_tab(view)
  return function()
    local itemid = algos.match_itemid(api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    if not entry:is_dir() then
      if util.is_valid_winid(view.win.old_winid) then
        if config.values.views.explorer.close_on_select then view.win:hide() end

        vim.cmd.tabedit(entry:get_path())
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_v_split(view)
  return function()
    local itemid = algos.match_itemid(api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    if not entry:is_dir() then
      if util.is_valid_winid(view.win.old_winid) then
        if config.values.views.explorer.close_on_select then view.win:hide() end

        api.nvim_set_current_win(view.win.old_winid)
        vim.cmd.vsplit(entry:get_path())
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_split(view)
  return function()
    local itemid = algos.match_itemid(api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    if not entry:is_dir() then
      if util.is_valid_winid(view.win.old_winid) then
        api.nvim_set_current_win(view.win.old_winid)
        if config.values.views.explorer.close_on_select then view.win:hide() end

        api.nvim_set_current_win(view.win.old_winid)
        vim.cmd.split(entry:get_path())
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_goto_parent(view)
  return function()
    local current_dir = view:getcwd()
    if not current_dir then return end

    local parent_dir = fn.fnamemodify(current_dir, ":h")
    if parent_dir == view:getcwd() then return end

    view:ch_root(parent_dir)
    if not util.if_any(view.root.children, function(child) return child.itemid == view.root.itemid end) then
      view.root:add_child(view.root.itemid, view.root)
    end

    api.nvim_exec_autocmds("User", { pattern = "RefreshView" })
  end
end

---@param view FylerExplorerView
function M.n_goto_cwd(view)
  return function()
    if view:getcwd() == fs.getcwd() then return end

    view:ch_root(fs.getcwd())
    api.nvim_exec_autocmds("User", { pattern = "RefreshView" })
  end
end

---@param view FylerExplorerView
function M.n_goto_node(view)
  return function()
    local itemid = algos.match_itemid(api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    if entry:is_dir() then
      view:ch_root(entry:get_path())
      api.nvim_exec_autocmds("User", { pattern = "RefreshView" })
    else
      M.n_select(view)()
    end
  end
end

---@param view FylerExplorerView
function M.n_toggle_preview(view)
  return function()
    local itemid = algos.match_itemid(vim.api.nvim_get_current_line())
    if not itemid then return end

    local entry = store.get_entry(itemid)
    local function open_entry(path)
      if util.is_valid_winid(view.win.old_winid) then
        vim.api.nvim_win_call(view.win.old_winid, function() vim.cmd("keepjumps edit " .. path) end)
      end
    end
    view.preview = view.preview or {
      enabled = false,
      initial_path = nil,
    }
    view.preview.enabled = not view.preview.enabled

    local function toggle_keymap(mode, lhs, callback, enabled)
      if enabled then
        vim.keymap.set(mode, lhs, callback, { buffer = view.win.bufnr })
      else
        pcall(vim.keymap.del, mode, lhs, { buffer = view.win.bufnr })
      end
    end
    local function preview_move(direction)
      vim.cmd("normal! " .. direction)
      local next_id = algos.match_itemid(vim.api.nvim_get_current_line())
      if next_id then open_entry(store.get_entry(next_id):get_path()) end
    end

    toggle_keymap("n", "j", function() preview_move("j") end, view.preview.enabled)
    toggle_keymap("n", "k", function() preview_move("k") end, view.preview.enabled)

    if view.preview.enabled then
      -- Store the entry only when entering preview mode
      view.preview.initial_path = vim.api.nvim_buf_get_name(view.win.old_bufnr)
      open_entry(entry:get_path())
    else
      -- Restore the initial entry when exiting preview mode
      if view.preview.initial_path then open_entry(view.preview.initial_path) end
      view.preview.initial_path = nil
    end
  end
end

---@param view FylerExplorerView
---@param tbl table
---@return table
local function get_tbl(view, tbl)
  local lines = {}
  if not view then return lines end
  if not vim.tbl_isempty(tbl.copy) then
    table.insert(lines, { { str = "COPY", hl = "FylerConfirmYellow" } })
    for _, change in ipairs(tbl.copy) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view:getcwd(), change.src), hl = "FylerConfirmGrey" },
        { str = " > " },
        { str = fs.relpath(view:getcwd(), change.dst), hl = "FylerConfirmGrey" },
      })
    end
    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.move) then
    table.insert(lines, { { str = "MOVE", hl = "FylerConfirmYellow" } })
    for _, change in ipairs(tbl.move) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view:getcwd(), change.src), hl = "FylerConfirmGrey" },
        { str = " > " },
        { str = fs.relpath(view:getcwd(), change.dst), hl = "FylerConfirmGrey" },
      })
    end

    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.create) then
    table.insert(lines, { { str = "CREATE", hl = "FylerConfirmGreen" } })
    for _, change in ipairs(tbl.create) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view:getcwd(), change), hl = "FylerConfirmGrey" },
      })
    end

    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.delete) then
    table.insert(lines, { { str = "DELETE", hl = "FylerConfirmRed" } })
    for _, change in ipairs(tbl.delete) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view:getcwd(), change), hl = "FylerConfirmGrey" },
      })
    end

    table.insert(lines, { { str = "" } })
  end

  return lines
end

---@param changes table
---@return boolean
local function can_bypass(changes)
  if #changes.copy > 1 then return false end
  if #changes.move > 1 then return false end
  if #changes.create > 5 then return false end
  if not vim.tbl_isempty(changes.delete) then return false end
  return true
end

---@param view FylerExplorerView
function M.synchronize(view)
  return async(function()
    local changes = algos.compute_fs_actions(view)
    local can_sync = (function()
      if #changes.create == 0 and #changes.delete == 0 and #changes.move == 0 and #changes.copy == 0 then
        return true
      end

      if not config.values.views.explorer.confirm_simple then
        return confirm_view.open(get_tbl(view, changes), "(y/n)")
      end

      if can_bypass(changes) then return true end

      return confirm_view.open(get_tbl(view, changes), "(y/n)")
    end)()

    if can_sync then
      for _, change in ipairs(changes.copy) do
        local err, success = fs.copy(change.src, change.dst)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.move) do
        local err, success = fs.move(change.src, change.dst)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.create) do
        local err, success = fs.create(change)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.delete) do
        local err, success = fs.delete(change)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end
    end

    vim.schedule(function() api.nvim_exec_autocmds("User", { pattern = "RefreshView" }) end)
  end)
end

---@param view FylerExplorerView
function M.refreshview(view)
  return async(function(arg)
    arg = arg or {}
    arg.data = arg.data or {}

    if not util.is_valid_bufnr(view.win.bufnr) then return end

    view.root:update()

    -- Block coroutine until "fast_event" passed away
    await_schedule()

    local status_map = config.values.views.explorer.git_status and git.status_map() or nil
    local cache_undolevels
    view.win.ui:render {
      ui_lines = ui.Explorer(algos.tree_table_from_node(view).children, status_map),

      before = function()
        cache_undolevels = vim.bo[view.win.bufnr].undolevels
        vim.bo[view.win.bufnr].undolevels = -1
      end,

      after = function()
        if arg.data.after then arg.data.after() end
        if not view.win:has_valid_bufnr() then return end

        vim.bo[view.win.bufnr].undolevels = cache_undolevels
        api.nvim_exec_autocmds("User", { pattern = "DrawIndentscope" })
      end,
    }
  end)
end

function M.constrain_cursor(view)
  return function()
    local cur = api.nvim_get_current_line()
    local itemid = algos.match_itemid(cur)
    if not itemid then return end

    local _, ub = string.find(cur, itemid)
    if not view.win:has_valid_winid() then return end

    local row, col = util.unpack(api.nvim_win_get_cursor(view.win.winid))
    if col <= ub then api.nvim_win_set_cursor(view.win.winid, { row, ub + 1 }) end
  end
end

---@param view FylerExplorerView
function M.try_focus_buffer(view)
  return awaited_queue:wrap(function(arg)
    if not fs.is_valid_path(arg.file) then return end
    if not a.util.is_valid_winid(view.win.winid) then return end

    if string.match(arg.file, "^fyler://*") then
      if not view.win.old_bufnr then return end
      if not a.util.is_valid_bufnr(view.win.old_bufnr) then return end

      local old_bufname = fn.bufname(view.win.old_bufnr)
      if old_bufname == "" or string.match(old_bufname, "^fyler://*") then return end

      arg.file = fs.abspath(old_bufname)
    end

    local current_dir = view:getcwd()
    if not current_dir then return end
    if not vim.startswith(arg.file, current_dir) then view:ch_root(fn.fnamemodify(arg.file, ":h")) end

    local relpath = fs.relpath(view:getcwd(), arg.file)
    if not relpath then return end

    local focused_node = view.root
    local last_visit = 0
    local parts = vim.split(relpath, "/")
    focused_node:update()

    for i, part in ipairs(parts) do
      local child = util.tbl_find(
        focused_node.children,
        function(child) return store.get_entry(child.itemid).name == part end
      )

      if not child then break end
      if store.get_entry(child.itemid):is_dir() then
        child.open = true
        child:update()
      end

      focused_node, last_visit = child, i
    end

    if last_visit ~= #parts then return end

    vim.schedule(function()
      api.nvim_exec_autocmds("User", {
        pattern = "RefreshView",
        data = {
          after = function()
            if not view.win:has_valid_winid() then return end
            local buf_lines = api.nvim_buf_get_lines(view.win.bufnr, 0, -1, false)
            for ln, buf_line in ipairs(buf_lines) do
              if buf_line:find(focused_node.itemid) then api.nvim_win_set_cursor(view.win.winid, { ln, 0 }) end
            end
          end,
        },
      })
    end)
  end)
end

local extmark_namespace = api.nvim_create_namespace("FylerIndentScope")

---@param view FylerExplorerView
function M.draw_indentscope(view)
  local function draw_line(ln)
    if not view.win:has_valid_bufnr() then return end

    local cur_line = util.unpack(api.nvim_buf_get_lines(view.win.bufnr, ln - 1, ln, false))
    local cur_indent = #algos.match_indent(cur_line)
    if cur_indent == 0 then return end

    local indent_depth = math.floor(cur_indent * 0.5)
    for i = 1, indent_depth do
      api.nvim_buf_set_extmark(view.win.bufnr, extmark_namespace, ln - 1, 0, {
        hl_mode = "combine",
        virt_text = {
          {
            config.values.views.explorer.indentscope.marker,
            config.values.views.explorer.indentscope.group,
          },
        },
        virt_text_pos = "overlay",
        virt_text_win_col = (i - 1) * 2,
      })
    end
  end

  return function()
    if not view.win:has_valid_bufnr() then return end
    if not config.values.views.explorer.indentscope.enabled then return end

    api.nvim_buf_clear_namespace(view.win.bufnr, extmark_namespace, 0, -1)
    for i = 1, api.nvim_buf_line_count(view.win.bufnr) do
      draw_line(i)
    end
  end
end

return M
