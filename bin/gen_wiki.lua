local FORMATTING = {
  heading_base = 2,
  strip_modeline = true,
  strip_separators = true,
  convert_links = true,
  indentation = 2,
}

---@param lines string[]
---@return table[]
local function parse_vimdoc(lines)
  local sections = {}
  local current = { lines = {} }

  for _, line in ipairs(lines) do
    if line:match('^%-%-%-%-') then
      if current and current.tag then table.insert(sections, current) end
      current = { lines = {} }
    elseif current then
      table.insert(current.lines, line)
      if not current.tag then
        local tag = line:match('^%s*%*([%w%.%-_]+)%*%s*$')
        if tag then current.tag = tag end
      end
      if not current.title then
        local title = line:match('^(.+)%~$')
        if title and #vim.trim(title) > 0 then current.title = vim.trim(title) end
      end
    end
  end

  if current and current.tag then table.insert(sections, current) end

  return sections
end

---@param section { tag: string, title: string|nil, lines: string[] }
---@return string
local function render_config_section(section)
  local result = {}
  local in_code = false
  local escaped_tag = vim.pesc(section.tag)
  local tag_pattern = '^%s*%*' .. escaped_tag .. '%*%s*$'

  for _, line in ipairs(section.lines) do
    if line:match(tag_pattern) then
    elseif FORMATTING.strip_separators and line:match('^%-%-%-%-') then
    elseif in_code and line:match('^<%s*$') then
      table.insert(result, '```')
      in_code = false
    elseif not in_code and line:match('^>(%w*)%s*$') then
      local lang = line:match('^>(%w*)%s*$')
      table.insert(result, '```' .. lang)
      in_code = true
    elseif in_code then
      table.insert(result, line:sub(FORMATTING.indentation + 1))
    elseif FORMATTING.strip_modeline and line:match('^%s*vim:') then
    elseif line:match('^(.+)%~$') then
    else
      local text = line
      if FORMATTING.convert_links then text = text:gsub('|([^|]+)|', '%1') end
      text = text.gsub(text, '%s+$', '')
      table.insert(result, text)
    end
  end

  return table.concat(result, '\n')
end

local args = arg or {}
local output_path = args[1] or 'wiki.md'
local section_tag = args[2] or 'fyler.configuration'
local doc_path = args[3] or 'doc/fyler.txt'

local sections = parse_vimdoc(vim.fn.readfile(doc_path))

local function find_config_section()
  for _, s in ipairs(sections) do
    if s.tag == section_tag then return s end
  end
  return nil
end

local config_section = find_config_section()
if not config_section then
  print(('Section %q not found in %s'):format(section_tag, doc_path))
  return
end

local content = vim.trim(render_config_section(config_section))

vim.fn.writefile(vim.split(content, '\n'), output_path)
print(('%s has been generated successfully'):format(output_path))
