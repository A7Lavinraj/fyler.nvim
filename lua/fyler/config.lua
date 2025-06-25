---@class FylerConfig
local M = {}

local defaults = {
  default_explorer = false,
  close_on_select = true,
  views = {
    confirm = {
      width = 0.5,
      height = 0.4,
      kind = "float",
      border = "single",
    },
    file_tree = {
      width = 0.8,
      height = 0.8,
      kind = "float",
      border = "single",
    },
  },
  mappings = {
    confirm = {
      n = {
        ["y"] = "Confirm",
        ["n"] = "Discard",
      },
    },
    file_tree = {
      n = {
        ["q"] = "CloseView",
        ["<CR>"] = "Select",
        ["<C-CR>"] = "SelectRecursive",
      },
    },
  },
  icon_provider = 'mini.icons',
}

M.values = vim.deepcopy(defaults, true)

---@param name string
function M.get_view(name)
  assert(name, "name is required")

  return M.values.views[name]
end

---@param name string
function M.get_mappings(name)
  assert(name, "name is required")

  return M.values.mappings[name]
end

---@param name string
function M.get_reverse_mappings(name)
  assert(name, "name is required")

  local mappings = M.get_mappings(name)
  local reverse_mappings = {}

  for _, map in pairs(mappings) do
    for key, val in pairs(map) do
      reverse_mappings[val] = key
    end
  end

  return reverse_mappings
end

function M.setup(opts)
  opts = opts or {}
  M.values = vim.tbl_deep_extend("force", defaults, opts)
end

return M
