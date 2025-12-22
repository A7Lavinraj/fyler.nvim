<div align="center">
  <h1>Fyler.nvim</h1>
  <table>
    <tr>
      <td>
        <strong>A file manager for <a href="https://neovim.io">Neovim</a></strong>
      </td>
    </tr>
  </table>
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

<div align="center">
  <img
    width="1920"
    height="1080"
    alt="image"
    src="https://github.com/user-attachments/assets/036ebf84-0053-4930-ae91-c0ae95bb417d"
  />
</div>

## Installation

> [!IMPORTANT]
>
> Both **Stable** and **Latest** versions are explained on the
> [WIKI PAGE](https://github.com/A7Lavinraj/fyler.nvim/wiki/installation) in details.

#### Stable

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  branch = "stable",  -- Use stable branch for production
  lazy = false, -- Necessary for `default_explorer` to work properly
  opts = {}
}
```

#### Latest

```lua
{
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  lazy = false, -- Necessary for `default_explorer` to work properly
  opts = {}
}
```

## Usage

You can either open fyler by using the `Fyler` command:

```vim
:Fyler             " Open the finder
:Fyler dir=<cwd>   " Use a different directory path
:Fyler kind=<kind> " Open specified window kind directly

" Map it to a key
nnoremap <leader>e <cmd>Fyler<cr>
```

```lua
-- Or via lua api
vim.keymap.set("n", "<leader>e", "<cmd>Fyler<cr>", { desc = "Open Fyler View" })
```

Or using the lua api:

```lua
local fyler = require('fyler')

-- open using defaults
fyler.open()

-- open as a left most split
fyler.open({ kind = "split_left_most" })

-- open with different directory
fyler.open({ dir = "~" })

-- You can map this to a key
vim.keymap.set("n", "<leader>e", fyler.open, { desc = "Open fyler View" })

-- Wrap in a function to pass additional arguments
vim.keymap.set(
    "n",
    "<leader>e",
    function() fyler.open({ kind = "split_left_most" }) end,
    { desc = "Open Fyler View" }
)
```

> [!NOTE]
> Run `:help fyler.nvim` OR visit [wiki pages](https://github.com/A7Lavinraj/fyler.nvim/wiki) for more detailed explanation and live showcase.

### Credits

- [**GrugFar**](https://github.com/MagicDuck/grug-far.nvim)
- [**Mini.files**](https://github.com/nvim-mini/mini.files)
- [**Neogit**](https://github.com/NeogitOrg/neogit)
- [**Nvim-window-picker**](https://github.com/s1n7ax/nvim-window-picker)
- [**Oil**](https://github.com/stevearc/oil.nvim)
- [**Snacks**](https://github.com/folke/snacks.nvim)
- [**Telescope**](https://github.com/nvim-telescope/telescope.nvim)

---

<h4 align="center">Built with ❤️ for the Neovim community</h4>
<a href="https://github.com/A7Lavinraj/fyler.nvim/graphs/contributors">
  <img
    src="https://contrib.rocks/image?repo=A7Lavinraj/fyler.nvim&max=750&columns=20"
    alt="contributors"
  />
</a>
