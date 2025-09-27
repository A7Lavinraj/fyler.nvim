<div align="center">
  <br/>
  <br/>
  <br/>
  <img
    width="320"
    height="320"
    alt="Fyler.nvim Logo"
    src="https://github.com/user-attachments/assets/f0de0c60-5911-4aa4-bf13-9f16dc18e4b4"
  />
  <br/>
  <br/>
  <br/>
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
  <br/>
  <h4>
    <a href="https://youtube.com/playlist?list=PLE5gu3yOYmtiTiC1J3BysrcormCt_eWuq&si=L6yEiJI7rNuCp5cy">Live Streams</a>
    ·
    <a href="https://github.com/A7Lavinraj/fyler.nvim/wiki">Wiki Page</a>
  </h4>
</div>

## Showcase

<img
  alt="Showcase"
  src="https://github.com/user-attachments/assets/1984d7f5-d569-4fa9-a243-4938dca7a40c"
/>

## Features

### Completed

- [x] **File Operations** - Create, delete, move, and copy files and directories
- [x] **Git Integration** - Visual git status indicators for tracked files
- [x] **LSP Integration** - Enhanced file management with language server support
- [x] **Smart Navigation** - Auto-tracking of current buffer and directory navigation
- [x] **Telescope Integration** - Seamless integration with Telescope for enhanced workflow
- [x] **Customizable Interface** - Configurable mappings, icons, and window behavior
- [x] **Multiple Icon Providers** - Support for both mini.icons and nvim-web-devicons
- [x] **Indentation Guides** - Visual directory structure representation
- [x] **Netrw Hijacking** - Replace default file explorer
- [x] **Public API** - Programmatic access for advanced users
- [x] **User Commands** - Simple command interface

### Planned

- [ ] **File System Watching** - Real-time updates for file changes
- [ ] **Fuzzy Finding** - Built-in search capabilities
- [ ] **SSH Integration** - Remote file management support

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

-- Basic usage
fyler.open()

-- Open specific directory
fyler.open({ dir = "~/" })

-- Open with custom window layout
fyler.open({ kind = "split_left_most" })
```

## Configuration

Fyler.nvim works out of the box with sensible defaults. Here's the complete configuration reference:

```lua
require("fyler").setup({
  -- Close explorer when file is selected
  close_on_select = true,
  -- Auto-confirm simple file operations
  confirm_simple = false,
  -- Replace netrw as default explorer
  default_explorer = false,

  -- Git integration
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

  hooks = {
    -- function(path) end
    on_delete = nil,
    -- function(src_path, dst_path) end
    on_rename = nil,
    -- function(hl_groups, palette) end
    on_highlight = nil,
  },

  -- Directory icons
  icon = {
    directory_collapsed = nil,
    directory_empty = nil,
    directory_expanded = nil,
  },

  -- Icon provider (none, mini_icons or nvim_web_devicons)
  icon_provider = "mini_icons",

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

  popups = {
    permission = {
      -- Respective popup configuration:
      -- border
      -- height
      -- width
      -- left
      -- right
      -- top
      -- bottom
    }
  }

  -- Buffer tracking
  track_current_buffer = true,

  -- Window configuration
  win = {
    -- Window border style
    border = "single",
    -- Default window kind
    kind = "replace",

    -- Window kind presets
    kind_presets = {
      -- Define custom layouts
      -- Values: "(0,1]rel" for relative or "{1...}abs" for absolute
    },

    -- Buffer and window options
    buf_opts = {}, -- Custom buffer options
    win_opts = {}, -- Custom window options
  },
})
```

## Telescope Integration

Fyler.nvim includes a Telescope extension for enhanced directory navigation:

```lua
local telescope = require("telescope")

telescope.setup({
  extensions = {
    fyler_zoxide = {
      -- Extension configuration
    }
  }
})

telescope.load_extension("fyler_zoxide")
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

- [mini.nvim](https://github.com/nvim-telescope/telescope.nvim) - Clean, efficient plugin architecture
- [neogit](https://github.com/NeogitOrg/neogit) - Git integration patterns
- [plenary.nvim](https://github.com/nvim-telescope/telescope.nvim) - Utility functions
- [snacks.rename](https://github.com/folke/snacks.nvim/blob/main/docs/rename.md) - File renaming implementation
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finding and UI patterns

## License

This project is licensed under the Apache-2.0 License. See the repository for full license details.
