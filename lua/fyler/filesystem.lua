local algos = require 'fyler.algos'
local state = require 'fyler.state'
local filesystem = {}
local uv = vim.uv or vim.loop

function filesystem.synchronize_from_buffer()
  local window = state('windows'):get 'main' ---@type Fyler.Window
  local buf_lines = vim.api.nvim_buf_get_lines(window.bufnr, 0, -1, false)
  local changes = algos.get_changes(
    algos.get_snapshot_from_render_node(state('rendernodes'):get(uv.cwd() or vim.fn.getcwd(0))),
    algos.get_snapshot_from_buf_lines(buf_lines)
  )
  for _, change in ipairs(changes.create) do
    vim.notify(string.format('CREATE: %s', change))
    filesystem.create_fs_item(change)
  end
end

---@param path string
function filesystem.create_fs_item(path)
  local stat = uv.fs_stat(path)
  if stat then
    return
  end

  local path_type = string.sub(path, -1) == '/' and 'directory' or 'file'
  if path_type == 'directory' then
    local success = vim.fn.mkdir(path, 'p')
    if not success then
      return
    end
  else
    local parent_path = vim.fn.fnamemodify(path, ':h')
    if vim.fn.isdirectory(path) == 0 then
      local success = vim.fn.mkdir(parent_path, 'p')
      if not success then
        return
      end
    end

    local fd, err, err_name = uv.fs_open(path, 'w', 438)
    if not fd or err then
      vim.notify(err .. err_name, vim.log.levels.ERROR, { title = 'Fyler.nvim' })
      return
    end

    uv.fs_close(fd)
  end
end

---@param path string
function filesystem.delete_fs_item(path)
  local stat = uv.fs_stat(path)
  if not stat then
    return
  end
end

return filesystem
