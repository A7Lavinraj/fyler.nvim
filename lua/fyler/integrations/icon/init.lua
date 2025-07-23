---@param type string
---@param _ string
---@return string?, string?
local function default_icon_provider(type, _)
  if type == "directory" then
    return "D", "FylerFSDirectory"
  elseif type == "file" then
    return "F", "FylerFSFile"
  else
    return "*", ""
  end
end

return setmetatable({}, {
  __index = function(_, key)
    local status, icon_provider = pcall(require, string.format("fyler.integrations.icon.%s", key))
    if not status then
      return default_icon_provider
    end

    return function(...)
      local success, icon, hl = pcall(icon_provider.get_icon, ...)
      if not success then
        return default_icon_provider(...)
      end

      return icon, hl
    end
  end,
})
