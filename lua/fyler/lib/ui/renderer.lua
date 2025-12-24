local config = require "fyler.config"

---@class UiRenderer
---@field line string[]
---@field extmark table[]
---@field highlight table[]
---@field flag table
local Renderer = {}
Renderer.__index = Renderer

function Renderer.new()
  local instance = {
    line = {},
    extmark = {},
    highlight = {},
    flag = {
      in_row = false,
      row_base_line = 0, -- Track the starting line of current row
      column_offset = 0, -- Track horizontal offset for columns in row
    },
  }

  setmetatable(instance, Renderer)

  return instance
end

---@param component UiComponent
function Renderer:render(component)
  self.line = {}
  self.extmark = {}
  self.highlight = {}
  self.flag = {
    in_row = false,
    row_base_line = 0,
    column_offset = 0,
  }
  self:_render(component)
end

---@param component UiComponent
---@param current_col number|nil
---@return string|nil, number|nil
function Renderer:_render_text(component, current_col)
  local text_value = tostring(component.value or "")
  local highlight = component.option and component.option.highlight
  local width = #text_value

  if self.flag.in_row then
    current_col = current_col or 0

    if component.option and component.option.virt_text then
      width = #component.option.virt_text[1][1]
      table.insert(self.extmark, {
        line = self.flag.row_base_line,
        col = current_col,
        virt_text = component.option.virt_text,
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end

    if highlight then
      table.insert(self.highlight, {
        line = self.flag.row_base_line,
        col_start = current_col,
        col_end = current_col + #text_value,
        highlight_group = highlight,
      })
    end

    return text_value, current_col + width
  else
    if text_value then
      table.insert(self.line, text_value)
    end

    -- Now calculate line number after adding the text
    local current_line_idx = #self.line - 1

    if component.option and component.option.virt_text then
      table.insert(self.extmark, {
        line = current_line_idx,
        col = component.option.col or 0,
        virt_text = component.option.virt_text,
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end

    if highlight then
      table.insert(self.highlight, {
        line = current_line_idx,
        col_start = 0,
        col_end = #text_value,
        highlight_group = highlight,
      })
    end
  end
end

---@param component UiComponent
---@param current_col number|nil
---@return string|nil, number|nil
function Renderer:_render_nested_row_in_row(component, current_col)
  current_col = current_col or 0
  local nested_row_content = {}

  -- Render the nested row's children inline
  for _, child in ipairs(component.children) do
    if child.tag == "row" then
      error "Rows cannot be nested more than one level deep"
    end

    local text_part, new_col = self:_render_child_in_row(child, current_col)
    if text_part then
      table.insert(nested_row_content, text_part)
      current_col = new_col or current_col
    end
  end

  -- Concatenate all parts of the nested row
  local nested_row_text = table.concat(nested_row_content)

  return nested_row_text, current_col
end

---@param component UiComponent
---@param current_col number|nil
---@return string|nil, number|nil
function Renderer:_render_child_in_row(component, current_col)
  if component.tag == "text" then
    return self:_render_text(component, current_col)
  elseif component.tag == "column" then
    return self:_render_column_in_row(component, current_col)
  elseif component.tag == "row" then
    return self:_render_nested_row_in_row(component, current_col)
  else
    error("The row component does not support having a `" .. component.tag .. "` as a child")
  end
end

---@param component UiComponent
---@param current_col number|nil
---@return string|nil, number|nil
function Renderer:_render_column_in_row(component, current_col)
  current_col = current_col or 0
  local column_start_col = current_col
  local column_width = component:width()
  local column_lines = {}
  local column_highlights = {}
  local column_extmarks = {}

  -- Store current state
  local saved_line = vim.deepcopy(self.line)
  local saved_highlights = vim.deepcopy(self.highlight)
  local saved_extmarks = vim.deepcopy(self.extmark)
  local saved_flag = vim.deepcopy(self.flag)

  -- Reset for column rendering
  self.line = {}
  self.highlight = {}
  self.extmark = {}
  self.flag.in_row = false
  self.flag.column_offset = column_start_col

  -- Render column children
  for _, child in ipairs(component.children) do
    self:_render_child(child)
  end

  -- Capture column results
  column_lines = vim.deepcopy(self.line)
  column_highlights = vim.deepcopy(self.highlight)
  column_extmarks = vim.deepcopy(self.extmark)

  -- Restore state
  self.line = saved_line
  self.highlight = saved_highlights
  self.extmark = saved_extmarks
  self.flag = saved_flag

  -- Ensure we have enough lines in the main buffer
  local lines_needed = self.flag.row_base_line + #column_lines
  while #self.line < lines_needed do
    table.insert(self.line, "")
  end

  -- Apply column content to the main buffer with offset
  for i, line_content in ipairs(column_lines) do
    local target_line_idx = self.flag.row_base_line + i
    local current_line = self.line[target_line_idx] or ""

    -- Only add padding and content if the column actually has content
    if line_content and line_content ~= "" then
      -- Pad current line to reach column start position
      local padding_needed = column_start_col - #current_line
      if padding_needed > 0 then
        current_line = current_line .. string.rep(" ", padding_needed)
      end

      -- Append column content
      self.line[target_line_idx] = current_line .. line_content
    end
  end

  -- Apply column highlights with offset
  for _, hl in ipairs(column_highlights) do
    table.insert(self.highlight, {
      line = self.flag.row_base_line + hl.line,
      col_start = column_start_col + hl.col_start,
      col_end = column_start_col + hl.col_end,
      highlight_group = hl.highlight_group,
    })
  end

  -- Apply column extmarks with offset
  for _, extmark in ipairs(column_extmarks) do
    table.insert(self.extmark, {
      line = self.flag.row_base_line + extmark.line,
      col = column_start_col + (extmark.col or 0),
      virt_text = extmark.virt_text,
      virt_text_pos = extmark.virt_text_pos,
      hl_mode = extmark.hl_mode,
    })
  end

  -- Return empty string and new column position
  return "", column_start_col + column_width
end

---@param component UiComponent
function Renderer:_render_row(component)
  self.flag.in_row = true
  self.flag.row_base_line = #self.line

  local current_col = (config.values.views.finder.indentscope.level == 0) and 1 or 0
  local max_lines_in_row = 0

  -- First pass: calculate how many lines this row will need
  for _, child in ipairs(component.children) do
    if child.tag == "column" then
      local column_height = 0
      -- Count lines in column by simulating render
      local temp_renderer = Renderer.new()
      temp_renderer:render(child)
      column_height = #temp_renderer.line
      if column_height > max_lines_in_row then
        max_lines_in_row = column_height
      end
    else
      max_lines_in_row = math.max(max_lines_in_row, 1)
    end
  end

  -- Ensure we have enough lines
  for _ = 1, max_lines_in_row do
    table.insert(self.line, "")
  end

  -- Second pass: render children
  for _, child in ipairs(component.children) do
    local text_part, new_col = self:_render_child_in_row(child, current_col)
    if text_part and text_part ~= "" then
      -- For text components, update the first line of the row
      local target_line_idx = self.flag.row_base_line + 1
      local current_line = self.line[target_line_idx] or ""
      local padding_needed = current_col - #current_line
      if padding_needed > 0 then
        current_line = current_line .. string.rep(" ", padding_needed)
      end
      self.line[target_line_idx] = current_line .. text_part
    end
    current_col = new_col or current_col
  end

  self.flag.in_row = false
end

---@param component UiComponent
function Renderer:_render_column(component)
  for _, child in ipairs(component.children) do
    self:_render_child(child)
  end
end

---@param component UiComponent
function Renderer:_render_child(component)
  if component.tag == "text" then
    self:_render_text(component)
  elseif component.tag == "column" then
    self:_render_column(component)
  elseif component.tag == "row" then
    self:_render_row(component)
  else
    -- Handle unknown components by rendering their children
    if component.children then
      for _, child in ipairs(component.children) do
        self:_render_child(child)
      end
    end
  end
end

---@param component UiComponent
function Renderer:_render(component)
  if component.tag then
    -- If the component has a tag, render it as a specific component
    self:_render_child(component)
  elseif component.children then
    -- If no tag but has children, render children
    for _, child in ipairs(component.children) do
      self:_render_child(child)
    end
  end
end

return Renderer
