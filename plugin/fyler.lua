vim.api.nvim_create_user_command("Fyler", function(args)
  local opts = {}
  for _, farg in ipairs(args.fargs) do
    local k, v = require("fyler.lib.util").unpack(vim.split(farg, "="))
    opts[k] = v
  end

  require("fyler").open(opts)
end, {
  nargs = "*",
  complete = function(arglead, cmdline)
    local util = require "fyler.lib.util"
    if arglead:find "^kind=" then
      return util.tbl_map(vim.tbl_keys(require("fyler.config").values.views.finder.win.kinds), function(kind_preset)
        return string.format("kind=%s", kind_preset)
      end)
    end

    if arglead:find "^dir=" then
      return { "dir=" .. (vim.uv or vim.loop).cwd() }
    end

    return util.tbl_filter({ "kind=", "dir=" }, function(arg)
      return cmdline:match(arg) == nil
    end)
  end,
})
