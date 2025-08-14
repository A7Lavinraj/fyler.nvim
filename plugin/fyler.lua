if vim.g.loaded_fyler == 1 then return end
vim.g.loaded_fyler = 1

local util = require("fyler.lib.util")

FYLER_GLOBAL_STATE = {}

vim.api.nvim_create_user_command("Fyler", function(args)
  local opts = {}
  for _, farg in ipairs(args.fargs) do
    local key, value = util.unpack(vim.split(farg, "="))
    opts[key] = value
  end

  require("fyler").open(opts)
end, {
  nargs = "*",
  complete = function(arglead, cmdline)
    if arglead:find("^kind=") then
      return util.tbl_map(
        vim.tbl_keys(require("fyler.config").values.views.explorer.win.kind_presets),
        function(kind_preset) return string.format("kind=%s", kind_preset) end
      )
    end

    if arglead:find("^cwd=") then return { "cwd=" .. (vim.uv or vim.loop).cwd() } end

    return util.tbl_filter({ "kind=", "cwd=" }, function(arg) return cmdline:match(arg) == nil end)
  end,
})
