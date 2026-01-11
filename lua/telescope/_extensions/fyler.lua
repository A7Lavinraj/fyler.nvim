local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then error("Fyler.nvim requires telescope.nvim") end

local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local config = require("telescope.config")
local finders = require("telescope.finders")
local fyler = require("fyler")
local pickers = require("telescope.pickers")
local util = require("fyler.lib.util")

local default_opts = {
  sorting_strategy = "ascending",
  layout_config = {
    horizontal = {
      prompt_position = "top",
    },
  },
}

local finder = finders.new_async_job({
  command_generator = function() return { "zoxide", "query", "--list" } end,
  entry_maker = function(entry)
    if not entry or entry == "" then return nil end

    local display_name = vim.fn.fnamemodify(entry, ":t")
    return {
      value = entry,
      display = display_name .. " (" .. entry .. ")",
      ordinal = entry,
    }
  end,
})

return telescope.register_extension({
  exports = {
    setup = function(opts) default_opts = util.tbl_merge_force(default_opts, opts) end,
    zoxide = function()
      pickers
        .new(default_opts, {
          debounce = 100,
          prompt_title = "Fyler Zoxide",
          finder = finder,
          sorter = config.values.generic_sorter(),
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)

              if selection then fyler.open({ dir = selection.value }) end
            end)

            return true
          end,
        })
        :find()
    end,
  },
})
