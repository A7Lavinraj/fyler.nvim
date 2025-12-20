vim.api.nvim_create_user_command("Fyler", function(args)
  local util = require "fyler.lib.util"
  local opts = {}
  for _, farg in ipairs(args.fargs) do
    local k, v = util.unpack(vim.split(farg, "="))
    opts[k] = v
  end

  if opts.dir == nil then
    ---@type string[]|nil
    local range_lines = nil

    -- Check if the command was called from a visual mode mapping
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == vim.api.nvim_replace_termcodes("<C-v>", true, true, true) then
      -- We need to switch out of visual mode in order for the '> and '< marks
      -- to be set to the correct lines.
      -- Calling `"normal! " .. mode` achieves this by switching to normal mode
      -- and then immediately back to the original mode.
      vim.cmd("normal! " .. mode)
      range_lines = util.get_visual_selection()
    elseif args.range > 0 then
      -- Check if range start and end line are the same as the last visual selection.
      -- If so, use the visual selection including column offsets.
      -- This may have unexpected behavior if the user explicitly passes a range that
      -- matches the last visual selection and expects line-wise behavior.
      -- This is a limitation of Neovim's command ranges: https://github.com/neovim/neovim/issues/22297
      local visual_start_row = vim.api.nvim_buf_get_mark(0, "<")[1]
      local visual_end_row = vim.api.nvim_buf_get_mark(0, ">")[1]
      if visual_start_row == args.line1 and visual_end_row == args.line2 then
        range_lines = util.get_visual_selection()
      else
        range_lines = vim.api.nvim_buf_get_lines(0, args.line1 - 1, (args.line2 or args.line1), false)
      end
    end

    if range_lines and #range_lines > 0 then
      -- Just use the first line of the range - it doesn't make sense to use multiple lines as a directory path.
      -- In the future, we may want to treat multiple lines as multiple directories to open, but it's not clear how
      -- opening multiple directories would work currently.
      local dir = vim.trim(range_lines[1])
      if dir ~= "" then
        opts.dir = dir
      end
    end
  end

  require("fyler").open(opts)
end, {
  nargs = "*",
  range = true,
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
