---@module 'fyler.views.file_tree.struct'

local config = require("fyler.config")

---@alias Icon { text: string, hl: string }
---@alias ProviderFunction fun(fileMetadata:FileMetadata): Icon

local M = {}

---@param fileMetadata FileMetadata
---@return Icon
local function default_provider(fileMetadata)
  local icon

  if fileMetadata:is_broken_link() then
    icon = { text = "󰟢", hl = "FylerRed" }
  elseif fileMetadata:is_directory() then
    icon = { text = "󰉋", hl = "FylerBlue" }
  else
    icon = { text = "󰈔", hl = "" }
  end

  if fileMetadata:is_valid_link() then
    icon.hl = "FylerYellow"
  end

  return icon
end

---@param fileMetadata FileMetadata
---@return Icon
local function mini_icons_provider(fileMetadata)
  local status, text, hl =
    pcall(require("mini.icons").get, fileMetadata:resolved_type() or "", fileMetadata.name)
  if not status or not text then
    return default_provider(fileMetadata)
  end

  return { text = text, hl = hl or "" }
end

---@param fileMetadata FileMetadata
---@return Icon
local function nvim_web_devicons_provider(fileMetadata)
  local nvim_web_devicons = require("nvim-web-devicons")

  local extension = fileMetadata.name:match("[.]([^.]+)$")
  local text, hl = nvim_web_devicons.get_icon(fileMetadata.name, extension)

  if not text then
    return default_provider(fileMetadata)
  end

  return { text = text, hl = hl or "" }
end

---@return ProviderFunction
function M.get_provider()
  local config_provider = config.values.icon_provider

  if config_provider == "mini.icons" then
    if pcall(require, "mini.icons") then
      return mini_icons_provider
    else
      vim.notify(
        "Fyler.nvim: Trying to use mini.icons as icon provider, "
          .. "but could not find mini.icons module. "
          .. "Using default icons as fallback...",
        vim.log.levels.WARN
      )
      return default_provider
    end
  elseif config_provider == "nvim-web-devicons" then
    if pcall(require, "nvim-web-devicons") then
      return nvim_web_devicons_provider
    else
      vim.notify(
        "Fyler.nvim: Trying to use nvim-web-devicons as icon provider, "
          .. "but could not find nvim-web-devicons module. "
          .. "Using default icons as fallback...",
        vim.log.levels.WARN
      )
      return default_provider
    end
  elseif type(config_provider) == "function" then
    return config_provider
  else
    return default_provider
  end
end

return M
