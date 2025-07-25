local api = vim.api

local M = {}

---@param dec integer
local function to_hex(dec)
  return string.format("%06X", math.max(0, math.min(0xFFFFFF, math.floor(dec))))
end

-- https://github.com/NeogitOrg/neogit
---@param name string
---@return string|nil
local function get_fg(name)
  local color = api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_fg(color["link"])
  elseif color["reverse"] and color["bg"] then
    return "#" .. to_hex(color["bg"])
  elseif color["fg"] then
    return "#" .. to_hex(color["fg"])
  end
end

-- https://github.com/NeogitOrg/neogit
---@param name string
---@return string|nil
local function get_bg(name)
  local color = api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_bg(color["link"])
  elseif color["reverse"] and color["fg"] then
    return "#" .. to_hex(color["fg"])
  elseif color["bg"] then
    return "#" .. to_hex(color["bg"])
  end
end

local function build_palette()
  -- stylua: ignore start
  return {
    black     = "#000000",
    white     = "#ffffff",

    bg        = get_bg("Normal"),
    blue      = get_fg("Directory"),
    cyan      = get_fg("Operator"),
    dark_grey = get_fg("WhiteSpace"),
    fg        = get_fg("Normal"),
    green     = get_fg("String"),
    grey      = get_fg("Comment"),
    orange    = get_fg("SpecialChar"),
    red       = get_fg("Error"),
    yellow    = get_fg("WarningMsg"),
  }
  -- stylua: ignore end
end

---@param opts? FylerConfig
function M.setup(opts)
  opts = opts or {}

  local palette = build_palette()

  -- stylua: ignore start
  local hl_groups = {
    FylerConfirmGreen  = { fg = palette.green },
    FylerConfirmGrey   = { fg = palette.grey },
    FylerConfirmRed    = { fg = palette.red },
    FylerConfirmYellow = { fg = palette.yellow },
    FylerFSDirectory   = { fg = palette.blue },
    FylerFSFile        = { fg = palette.white },
    FylerFSLink        = { fg = palette.grey },
    FylerGitAdded      = { fg = palette.green },
    FylerGitConflict   = { fg = palette.red },
    FylerGitDeleted    = { fg = palette.red },
    FylerGitIgnored    = { fg = palette.red },
    FylerGitModified   = { fg = palette.yellow },
    FylerGitRenamed    = { fg = palette.yellow },
    FylerGitStaged     = { fg = palette.green },
    FylerGitUnstaged   = { fg = palette.orange },
    FylerGitUntracked  = { fg = palette.cyan },
    FylerIndentMarker  = { fg = palette.dark_grey },
  }
  -- stylua: ignore end

  if opts.on_highlights then
    opts.on_highlights(hl_groups, palette)
  end

  for key, val in pairs(hl_groups) do
    api.nvim_set_hl(0, key, val)
  end
end

return M
