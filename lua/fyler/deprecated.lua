local M = {}

local warnings = {}

local function split_path(path)
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end
  return parts
end

local function get_nested(tbl, path)
  local parts = split_path(path)
  local current = tbl

  for _, part in ipairs(parts) do
    if type(current) ~= "table" then return nil end
    current = current[part]
    if current == nil then return nil end
  end

  return current
end

local function set_nested(tbl, path, value)
  local parts = split_path(path)
  local current = tbl

  for i = 1, #parts - 1 do
    local part = parts[i]
    if type(current[part]) ~= "table" then current[part] = {} end
    current = current[part]
  end

  current[parts[#parts]] = value
end

local function delete_nested(tbl, path)
  local parts = split_path(path)
  local current = tbl

  for i = 1, #parts - 1 do
    local part = parts[i]
    if type(current) ~= "table" or current[part] == nil then return end
    current = current[part]
  end

  current[parts[#parts]] = nil
end

local function path_exists(tbl, path) return get_nested(tbl, path) ~= nil end

local function format_warning(warning)
  local lines = {}
  local rule = warning.rule

  table.insert(lines, string.format("Deprecated configuration detected: '%s'", warning.path))

  if rule.message then table.insert(lines, "  " .. rule.message) end

  if rule.version then table.insert(lines, string.format("  Deprecated in: v%s", rule.version)) end

  if rule.removal_version then table.insert(lines, string.format("  Will be removed in: v%s", rule.removal_version)) end

  if rule.to then
    table.insert(lines, string.format("  Use '%s' instead", rule.to))
  else
    table.insert(lines, "  This option has been removed")
  end

  table.insert(lines, "  " .. warning.suggestion)

  return table.concat(lines, "\n")
end

local function show_warnings()
  if #warnings == 0 then return end

  local message_parts = {
    "Fyler: Deprecated configuration options detected",
    string.rep("=", 60),
  }

  for _, warning in ipairs(warnings) do
    table.insert(message_parts, "")
    table.insert(message_parts, format_warning(warning))
  end

  table.insert(message_parts, "")
  table.insert(message_parts, string.rep("=", 60))
  table.insert(message_parts, "Please update your configuration to avoid future issues.")
  table.insert(message_parts, "See :h Fyler.Config for current options.")

  local full_message = table.concat(message_parts, "\n")

  vim.notify(full_message, vim.log.levels.WARN)
end

local function apply_rule(config, rule)
  if not path_exists(config, rule.from) then return false end

  local old_value = get_nested(config, rule.from)

  local new_value = old_value
  if rule.transform then new_value = rule.transform(old_value, config) end

  if rule.to then set_nested(config, rule.to, new_value) end

  delete_nested(config, rule.from)

  local suggestion
  if rule.to then
    if rule.transform then
      suggestion = string.format("Update your config: %s = <transformed_value>", rule.to)
    else
      suggestion = string.format("Update your config: %s = %s", rule.to, vim.inspect(old_value))
    end
  else
    suggestion = string.format("Remove '%s' from your configuration", rule.from)
  end

  table.insert(warnings, {
    path = rule.from,
    rule = rule,
    suggestion = suggestion,
  })

  return true
end

function M.migrate(user_config, rules)
  warnings = {}

  local config = vim.deepcopy(user_config)

  for _, rule in ipairs(rules or {}) do
    apply_rule(config, rule)
  end

  if #warnings > 0 then show_warnings() end

  return config
end

function M.rename(from, to, opts)
  opts = opts or {}
  return vim.tbl_extend("force", {
    from = from,
    to = to,
    transform = nil,
  }, opts)
end

function M.remove(from, opts)
  opts = opts or {}
  return vim.tbl_extend("force", {
    from = from,
    to = nil,
    transform = nil,
  }, opts)
end

function M.transform(from, to, transform, opts)
  opts = opts or {}
  return vim.tbl_extend("force", {
    from = from,
    to = to,
    transform = transform,
  }, opts)
end

return M
