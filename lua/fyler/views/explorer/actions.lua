local a = require("fyler.lib.async")
local algos = require("fyler.views.explorer.algos")
local cache = require("fyler.cache")
local config = require("fyler.config")
local confirm_view = require("fyler.views.confirm")
local fs = require("fyler.lib.fs")
local store = require("fyler.views.explorer.store")
local ui = require("fyler.views.explorer.ui")
local util = require("fyler.lib.util")

local M = {}

local async = a.async
local await = a.await
local schedule_async = a.schedule_async
local fn = vim.fn
local api = vim.api

---@param view table
function M.n_close_view(view)
  return function()
    local success = pcall(api.nvim_win_close, view.win.winid, true)
    if not success then api.nvim_win_set_buf(view.win.winid, fn.bufnr("#", true)) end

    pcall(api.nvim_buf_delete, view.win.bufnr, { force = true })
  end
end

---@param view FylerExplorerView
function M.n_select(view)
  return function()
    local key = algos.match_id(api.nvim_get_current_line())
    if not key then return end

    local entry = store.get_entry(key)
    if entry:is_dir() then
      view.root:find(key):toggle()
      api.nvim_exec_autocmds("User", { pattern = "RefreshView" })
    else
      local recent_win = cache.get_entry("recent_win")

      if recent_win and util.is_valid_winid(recent_win) then
        fn.win_execute(recent_win, string.format("edit %s", entry:get_path()))
        fn.win_gotoid(recent_win)

        if config.values.views.explorer.close_on_select then view.win:hide() end
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_tab(view)
  return function()
    local key = algos.match_id(api.nvim_get_current_line())
    if not key then return end

    local entry = store.get_entry(key)
    if not entry:is_dir() then
      local recent_win = cache.get_entry("recent_win")

      if recent_win and util.is_valid_winid(recent_win) then
        fn.execute(string.format("tabedit %s", entry:get_path()))

        if config.values.views.explorer.close_on_select then view.win:hide() end
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_v_split(view)
  return function()
    local key = algos.match_id(api.nvim_get_current_line())
    if not key then return end

    local entry = store.get_entry(key)
    if not entry:is_dir() then
      local recent_win = cache.get_entry("recent_win")

      if recent_win and util.is_valid_winid(recent_win) then
        fn.win_gotoid(recent_win)
        fn.execute(string.format("vsplit %s", entry:get_path()))

        if config.values.views.explorer.close_on_select then view.win:hide() end
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_select_split(view)
  return function()
    local key = algos.match_id(api.nvim_get_current_line())
    if not key then return end

    local entry = store.get_entry(key)
    if not entry:is_dir() then
      local recent_win = cache.get_entry("recent_win")

      if recent_win and util.is_valid_winid(recent_win) then
        fn.win_gotoid(recent_win)
        fn.execute(string.format("split %s", entry:get_path()))

        if config.values.views.explorer.close_on_select then view.win:hide() end
      end
    end
  end
end

---@param view FylerExplorerView
function M.n_goto_parent(view)
  return function()
    local parent_dir = fn.fnamemodify(view.cwd, ":h")
    if parent_dir == view.cwd then return end

    M.n_close_view(view)()

    local instance = require("fyler.views.explorer").find_or_create(parent_dir)
    if not util.if_any(instance.root.children, function(child) return child.id == view.root.id end) then
      instance.root:add_child(instance.root.id, view.root)
    end

    instance:open {
      cwd = parent_dir,
      enter = true,
      kind = view.win.kind,
    }
  end
end

---@param view FylerExplorerView
function M.n_goto_cwd(view)
  return function()
    if view.cwd == fs.getcwd() then return end

    local cwd = fs.getcwd()
    local id = store.find_entry(function(_, y) return y.path == cwd end)
    local cwd_node = view.root:find(id)

    local instance = require("fyler.views.explorer").find_or_create(cwd)
    if cwd_node then instance.root = cwd_node end

    M.n_close_view(view)()

    instance:open {
      cwd = fs.getcwd(),
      enter = true,
      kind = view.win.kind,
    }
  end
end

---@param view FylerExplorerView
function M.n_goto_node(view)
  return function()
    local id = algos.match_id(api.nvim_get_current_line())
    if not id then return end

    local entry = store.get_entry(id)
    if entry:is_dir() then
      M.n_close_view(view)()

      local instance = require("fyler.views.explorer").find_or_create(entry:get_path())
      instance:open {
        cwd = entry:get_path(),
        enter = true,
        kind = view.win.kind,
      }
    else
      M.n_select(view)()
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
        { str = fs.relpath(view.cwd, change.src), hl = "FylerConfirmGrey" },
        { str = " > " },
        { str = fs.relpath(view.cwd, change.dst), hl = "FylerConfirmGrey" },
      })
    end
    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.move) then
    table.insert(lines, { { str = "MOVE", hl = "FylerConfirmYellow" } })

    for _, change in ipairs(tbl.move) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view.cwd, change.src), hl = "FylerConfirmGrey" },
        { str = " > " },
        { str = fs.relpath(view.cwd, change.dst), hl = "FylerConfirmGrey" },
      })
    end

    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.create) then
    table.insert(lines, { { str = "CREATE", hl = "FylerConfirmGreen" } })

    for _, change in ipairs(tbl.create) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view.cwd, change), hl = "FylerConfirmGrey" },
      })
    end

    table.insert(lines, { { str = "" } })
  end

  if not vim.tbl_isempty(tbl.delete) then
    table.insert(lines, { { str = "DELETE", hl = "FylerConfirmRed" } })

    for _, change in ipairs(tbl.delete) do
      table.insert(lines, {
        { str = "| " },
        { str = fs.relpath(view.cwd, change), hl = "FylerConfirmGrey" },
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
        return await(confirm_view.open, get_tbl(view, changes), "(y/n)")
      end

      if can_bypass(changes) then return true end

      return await(confirm_view.open, get_tbl(view, changes), "(y/n)")
    end)()

    if can_sync then
      for _, change in ipairs(changes.copy) do
        local err, success = await(fs.copy, change.src, change.dst)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.move) do
        local err, success = await(fs.move, change.src, change.dst)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.create) do
        local err, success = await(fs.create, change)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end

      for _, change in ipairs(changes.delete) do
        local err, success = await(fs.delete, change)
        if not success then vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end) end
      end
    end

    vim.schedule(function() api.nvim_exec_autocmds("User", { pattern = "RefreshView" }) end)
  end)
end

---@param view FylerExplorerView
---@param on_render function
function M.refreshview(view, on_render)
  return async(function()
    await(view.root.update, view.root)

    if not (view.win:has_valid_winid() and view.win:has_valid_bufnr()) then return end
    vim.bo[view.win.bufnr].undolevels = -1

    view.win.ui:render {
      ui_lines = await(ui.Explorer, algos.tree_table_from_node(view).children),
      on_render = vim.schedule_wrap(function()
        if on_render then on_render() end
        if view.win:has_valid_bufnr() then
          vim.bo[view.win.bufnr].undolevels = vim.go.undolevels
          M.draw_indentscope(view)()
        end
      end),
    }
  end)
end

function M.constrain_cursor(view)
  return function()
    local cur = api.nvim_get_current_line()
    local id = algos.match_id(cur)
    if not id then return end

    local _, ub = string.find(cur, id)
    if not view.win:has_valid_winid() then return end

    local row, col = util.unpack(api.nvim_win_get_cursor(view.win.winid))
    if col <= ub then api.nvim_win_set_cursor(view.win.winid, { row, ub + 1 }) end
  end
end

---@param view FylerExplorerView
function M.try_focus_buffer(view)
  return schedule_async(function(arg)
    if not fs.is_valid_path(arg.file) then return end

    if not view.win:has_valid_winid() then return end

    if string.match(arg.file, "^fyler://*") then
      local recent_win = cache.get_entry("recent_win")

      if type(recent_win) ~= "number" then return end

      if not util.is_valid_winid(recent_win) then return end

      local recent_bufname = fn.bufname(api.nvim_win_get_buf(recent_win))
      if recent_bufname == "" or string.match(recent_bufname, "^fyler://*") then return end

      arg.file = fs.abspath(recent_bufname)
    end

    if not vim.startswith(arg.file, view.cwd) then
      require("fyler").open {
        cwd = fn.fnamemodify(arg.file, ":h"),
        enter = fn.bufname("%") == view.win.bufname,
      }
    end

    local relpath = fs.relpath(view.cwd, arg.file)
    if not relpath then return end

    local focused_node = view.root
    local last_visit = 0
    local parts = vim.split(relpath, "/")

    await(focused_node.update, focused_node)

    for i, part in ipairs(parts) do
      local child = util.tbl_find(
        focused_node.children,
        function(child) return store.get_entry(child.id).name == part end
      )

      if not child then break end

      if store.get_entry(child.id):is_dir() then
        child.open = true
        await(child.update, child)
      end

      focused_node, last_visit = child, i
    end

    if last_visit ~= #parts then return end

    M.refreshview(view, function()
      if not view.win:has_valid_winid() then return end

      local buf_lines = api.nvim_buf_get_lines(view.win.bufnr, 0, -1, false)
      for ln, buf_line in ipairs(buf_lines) do
        if buf_line:find(focused_node.id) then api.nvim_win_set_cursor(view.win.winid, { ln, 0 }) end
      end
    end)()
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
