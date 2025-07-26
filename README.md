# Fyler.nvim

A modern neovim file tree which can edit your file system like a buffer

![License](https://img.shields.io/github/license/A7Lavinraj/fyler.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41)
![Stars](https://img.shields.io/github/stars/A7Lavinraj/fyler.nvim?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41)

![showcase](https://github.com/user-attachments/assets/c1dca603-7199-4a90-9a26-50dda96dec6e)

## Installation

> [!IMPORTANT]
> Please be careful while choosing between `stable` and `latest` version.
> `stable` branch will only get updates on releases.
> on the other hand `latest` branch updates frequently.

### Stable version

<details open>
  <summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a> (recommended)</summary>

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "echasnovski/mini.icons" },
  branch = "stable",
  opts = {} -- check the default options in the README.md
}
```

</details>

### Latest version

<details open>
  <summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a> (recommended)</summary>

```lua
-- `mini-icons` variant
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "echasnovski/mini.icons" },
  opts = {} -- check the default options in the README.md
}

-- `nvim-web-devicons` variant
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = { -- check the default options in the README.md
    icon_provider = "nvim-web-devicons",
  }
}
```

</details>

<details>
  <summary><a href="https://github.com/echasnovski/mini.deps">mini.deps</a></summary>

```lua
add({
  source = 'A7Lavinraj/fyler.nvim',
  depends = { 'echasnovski/mini.icons' },
})
```

</details>

<details open>
  <summary>(Default configuration)</summary>

```lua
local defaults = {
  -- Allow user to confirm simple edits
  auto_confirm_simple_edits = false,

  -- NETRW Hijacking:
  -- The plugin will replace most of the netrw command
  -- By default this option is disable to avoid any incompatibility
  default_explorer = false,

  -- Close open file:
  -- This enable user to close fyler window on opening a file
  close_on_select = true,

  -- Defines icon provider used by fyler, integrated ones are below:
  -- - "mini-icons"
  -- - "nvim-web-devicons"
  -- It also accepts `fun(type, name): icon: string, highlight: string`
  icon_provider = "mini-icons",

  -- Controls whether to show git status or not
  git_status = true,

  -- Controls behaviour of indentation marker
  indentscope = {
    enabled = true,
    group = "FylerIndentMarker",
    marker = "│",
  },

  -- A function allow user to override highlight groups
  -- function definition:
  --[[
    function(hl_groups: table, palette: table)
      hl_groups.FylerIndentMarker = { fg = palette.white }
      ...
    end
  ]]--
  on_highlights = nil,

  -- Views configuration:
  -- Every view config contains following options to be customized
  -- `width` a number in (0, 1] for relative size or [1, ...] for absolute size
  -- `height` a number in (0, 1] for relative size or [1, ...] for absolute size

  -- `kind` could be as following:
  -- 'float',
  -- 'split:left',
  -- 'split:above',
  -- 'split:right',
  -- 'split:below'
  -- 'split:leftmost',
  -- 'split:abovemost',
  -- 'split:rightmost',
  -- 'split:belowmost'

  -- for `border` |:help winborder|
  views = {
    confirm = {
      width = 0.8,
      height = 0.8,
      kind = "float",
      border = "single",
      buf_opts = {
        buflisted = false,
        modifiable = false,
      },
      win_opts = {
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
        wrap = false,
      },
    },
    explorer = {
      width = 0.8,
      height = 0.8,
      kind = "float",
      border = "single",
      buf_opts = {
        buflisted = false,
        buftype = "acwrite",
        filetype = "fyler",
        syntax = "fyler",
      },
      win_opts = {
        concealcursor = "nvic",
        conceallevel = 3,
        cursorline = true,
        number = true,
        relativenumber = true,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
        wrap = false,
      },
    },
  },

  -- Mappings:
  -- mappings can be customized by action names which are local to their view
  mappings = {
    confirm = {
      n = {
        ["y"] = "Confirm",
        ["n"] = "Discard",
      },
    },
    explorer = {
      n = {
        ["q"] = "CloseView",
        ["<CR>"] = "Select",
      },
    },
  },
}
```

</details>

> [!TIP]
> Visit [configuration recipe](https://github.com/A7Lavinraj/fyler.nvim/wiki#configuration-recipe)
> section on plugin wiki to deeply explore configuration options

## Usage

There is an user command `Fyler` which optionally accepts two options:

- kind
- cwd

```vim
" Open fyler with specific window kind
:Fyler kind=float
:Fyler kind=split:left
:Fyler kind=split:right
:Fyler kind=split:above
:Fyler kind=split:below
:Fyler kind=split:leftmost
:Fyler kind=split:rightmost
:Fyler kind=split:abovemost
:Fyler kind=split:belowmost

" Open fyler with specific directory
:Fyler cwd=/home/user/.config/nvim
```

## TODOS

- [x] Basic file operations `CREATE | DELETE | MOVE`
- [x] User command to change behaviour on startup
- [x] Hijack NETRW
- [x] Track current buffer
- [x] GIT integration
- [x] Indentation guides
- [x] Buffer-Explorer synchronization
- [ ] File system watching
- [ ] LSP integration
- [ ] SSH integration
- [ ] Fuzzy finding

## Have problems with fyler.nvim?

1. Search for existing [issues](https://github.com/A7Lavinraj/fyler.nvim/issues)
2. If related issue is not there then open a new one

## Want to contribute to this project?

- Please read the [CONTRIBUTING.md](https://github.com/A7Lavinraj/fyler.nvim/blob/main/CONTRIBUTING.md)

## Similar plugins

- [oil.nvim](https://github.com/stevearc/oil.nvim)
- [mini.files](https://github.com/echasnovski/mini.files)

## Codebase inspiration

- [neogit](https://github.com/NeogitOrg/neogit)
- [telescope](https://github.com/nvim-telescope/telescope.nvim)

## Special thanks to all contributors

![Contributors](https://contrib.rocks/image?repo=A7Lavinraj/fyler.nvim)
