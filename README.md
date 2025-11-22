<div align="center">
  <h1>Fyler.nvim</h1>

  <p><strong>A modern file manager for Neovim with git integration, LSP support, and intuitive navigation</strong></p>

  <div>
    <img
      alt="License"
      src="https://img.shields.io/github/license/A7Lavinraj/fyler.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41"
    />
    <img
      alt="Stars"
      src="https://img.shields.io/github/stars/A7Lavinraj/fyler.nvim?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41"
    />
  </div>
</div>

<br>

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/036ebf84-0053-4930-ae91-c0ae95bb417d" />

## Installation

### Stable Version (Recommended)

The stable branch updates only on releases and provides the most reliable experience.

**Using Lazy.nvim:**

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  branch = "stable",
  opts = {}
}
```

**Using Mini.deps:**

```lua
add({
  source = "A7Lavinraj/fyler.nvim",
  depends = { "nvim-mini/mini.icons" },
  checkout = "stable",
})
```

### Latest Version

The main branch includes the newest features but may contain bugs.

**Using Lazy.nvim with mini.icons:**

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  opts = {}
}
```

**Using Lazy.nvim with nvim-web-devicons:**

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = { icon_provider = "nvim_web_devicons" }
}
```

## Quick Start

### Using Commands

```vim
:Fyler                    " Open with default options
:Fyler kind=split_left    " Open in specific window layout
:Fyler dir=~/projects     " Open specific directory
```

### Using Lua API

```lua
local fyler = require("fyler")

-- Open Fyler with optional settings
fyler.open({
  dir = "~/",              -- (Optional) Start in specific directory
  kind = "split_left_most" -- (Optional) Use custom window layout
})

-- Toggle Fyler with optional settings
fyler.toggle({
  dir = "~/",              -- (Optional) Start in specific directory
  kind = "split_left_most" -- (Optional) Use custom window layout
})
```

## Configuration

Fyler.nvim works out of the box with sensible defaults. Here's the complete configuration reference:

```lua
{
  hooks = {
    -- function(path) end
    on_delete = nil,
    -- function(src_path, dst_path) end
    on_rename = nil,
    -- function(hl_groups, palette) end
    on_highlight = nil,
  },
  integrations = {
    icon = "mini_icons",
  },
  views = {
    finder = {
      -- Close explorer when file is selected
      close_on_select = true,
      -- Auto-confirm simple file operations
      confirm_simple = false,
      -- Replace netrw as default explorer
      default_explorer = false,
      -- Move deleted files/directories to the system trash
      delete_to_trash = false,
      -- Git status
      git_status = {
        enabled = true,
        symbols = {
          Untracked = "?",
          Added = "+",
          Modified = "*",
          Deleted = "x",
          Renamed = ">",
          Copied = "~",
          Conflict = "!",
          Ignored = "#",
        },
      },
      -- Icons for directory states
      icon = {
        directory_collapsed = nil,
        directory_empty = nil,
        directory_expanded = nil,
      },
      -- Indentation guides
      indentscope = {
        enabled = true,
        group = "FylerIndentMarker",
        marker = "│",
      },
      -- Key mappings
      mappings = {
        ["q"] = "CloseView",
        ["<CR>"] = "Select",
        ["<C-t>"] = "SelectTab",
        ["|"] = "SelectVSplit",
        ["-"] = "SelectSplit",
        ["^"] = "GotoParent",
        ["="] = "GotoCwd",
        ["."] = "GotoNode",
        ["#"] = "CollapseAll",
        ["<BS>"] = "CollapseNode",
      },
      mappings_opts = {
        nowait = false,
        noremap = true,
        silent = true,
      },
      -- Current file tracking
      follow_current_file = true,
      -- File system watching(includes git status)
      watcher = {
        enabled = false,
      },
      -- Window configuration
      win = {
        border = vim.o.winborder == "" and "single" or vim.o.winborder,
        buf_opts = {
          filetype = "fyler",
          syntax = "fyler",
          buflisted = false,
          buftype = "acwrite",
          expandtab = true,
          shiftwidth = 2,
        },
        kind = "replace",
        kinds = {
          float = {
            height = "70%",
            width = "70%",
            top = "10%",
            left = "15%",
          },
          replace = {},
          split_above = {
            height = "70%",
          },
          split_above_all = {
            height = "70%",
            win_opts = {
              winfixheight = true, -- keep the window height fixed when other windows resize
            },
          },
          split_below = {
            height = "70%",
          },
          split_below_all = {
            height = "70%",
            win_opts = {
              winfixheight = true,
            },
          },
          split_left = {
            width = "70%",
          },
          split_left_most = {
            width = "30%",
            win_opts = {
              winfixwidth = true, -- keep the window width fixed when other windows resize
            },
          },
          split_right = {
            width = "30%",
          },
          split_right_most = {
            width = "30%",
            win_opts = {
              winfixwidth = true,
            },
          },
        },
        win_opts = {
          concealcursor = "nvic",
          conceallevel = 3,
          cursorline = false,
          number = false,
          relativenumber = false,
          winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC",
          wrap = false,
        },
      },
    },
  },
}
```

Enable `delete_to_trash` to send deletions to your operating system's trash (macOS `~/.Trash`, Linux XDG Trash, Windows Recycle Bin) instead of removing files permanently.
Fyler automatically performs a permanent delete if the target already lives inside the trash directory.

**Note**: When moving files across different filesystems (e.g., to a trash directory on a different drive), the operation automatically falls back to copy-then-delete, which may be slower for large files or directories. Windows operations include a 30-second timeout to prevent hanging.

## Telescope Extension

Fyler.nvim includes a Telescope extension for enhanced directory navigation:

```lua
local telescope = require("telescope")

telescope.setup({
  extensions = {
    fyler = {
      -- Extension configuration
    }
  }
})

telescope.load_extension("fyler")
```

## Documentation

- **Wiki**: Comprehensive documentation available on the [Wiki page](https://github.com/A7Lavinraj/fyler.nvim/wiki)
- **Live Streams**: Development streams on [YouTube](https://youtube.com/playlist?list=PLE5gu3yOYmtiTiC1J3BysrcormCt_eWuq&si=L6yEiJI7rNuCp5cy)
- **Stable Documentation**: [Stable branch documentation](https://github.com/A7Lavinraj/fyler.nvim/blob/stable/README.md)

## Contributing

We welcome contributions! Please read our [Contributing Guidelines](https://github.com/A7Lavinraj/fyler.nvim/blob/main/CONTRIBUTING.md) before submitting pull requests.

## Issues and Support

If you encounter any problems:

1. Search existing [issues](https://github.com/A7Lavinraj/fyler.nvim/issues) to see if your problem has been reported
2. If no related issue exists, please open a new one with detailed information

## Similar Projects

If fyler.nvim doesn't meet your needs, consider these alternatives:

- [mini.files](https://github.com/nvim-mini/mini.files)
- [oil.nvim](https://github.com/stevearc/oil.nvim)

## Acknowledgments

This project draws inspiration from several excellent Neovim plugins and libraries:

- [mini.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [neogit](https://github.com/NeogitOrg/neogit)
- [plenary.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [snacks.rename](https://github.com/folke/snacks.nvim/blob/main/docs/rename.md)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## License

This project is licensed under the Apache-2.0 License. See the repository for full license details.

## Special thanks to all contributors

<a href="https://github.com/A7Lavinraj/fyler.nvim/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=A7Lavinraj/fyler.nvim" alt="contributors" />
</a>
