local config = require("fyler.config")
local util = require("fyler.lib.util")

local M = {}

local severity_names = {
  [vim.diagnostic.severity.ERROR] = "Error",
  [vim.diagnostic.severity.WARN] = "Warn",
  [vim.diagnostic.severity.INFO] = "Info",
  [vim.diagnostic.severity.HINT] = "Hint",
}

local severity_hl = {
  [vim.diagnostic.severity.ERROR] = "FylerDiagnosticError",
  [vim.diagnostic.severity.WARN] = "FylerDiagnosticWarn",
  [vim.diagnostic.severity.INFO] = "FylerDiagnosticInfo",
  [vim.diagnostic.severity.HINT] = "FylerDiagnosticHint",
}

local function count_diagnostics_by_path()
  local lookup = {}

  if not vim.diagnostic then return lookup end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then
      name = vim.fs.normalize(name)

      local diagnostics = vim.diagnostic.get(bufnr)
      if diagnostics and #diagnostics > 0 then
        local counts = {}
        local highest_severity = nil

        for _, diag in ipairs(diagnostics) do
          local sev = diag.severity
          if sev then
            counts[sev] = (counts[sev] or 0) + 1
            highest_severity = highest_severity and math.min(highest_severity, sev) or sev
          end
        end

        lookup[name] = {
          counts = counts,
          highest_severity = highest_severity,
        }
      end
    end
  end

  return lookup
end

function M.map_entries(_, entries)
  local diag_by_path = count_diagnostics_by_path()
  local symbols = (config.values.views.finder.columns.diagnostic or {}).symbols or {}

  return util.tbl_map(entries, function(path)
    local normalized_path = vim.fs.normalize(path)

    local info = diag_by_path[normalized_path]
    if not info or not info.highest_severity then return { "", nil } end

    local sev = info.highest_severity
    local sev_name = severity_names[sev]
    local sev_symbol = sev_name and symbols[sev_name] or ""
    local count = info.counts[sev] or 0
    if count == 0 then return { "", nil } end

    -- local text = sev_symbol .. count
    local text = sev_symbol
    local hl = severity_hl[sev]

    return {
      text,
      hl,
    }
  end)
end

function M.map_entries_async(root_dir, entries, onmapped)
  vim.schedule(function() onmapped(M.map_entries(root_dir, entries)) end)
end

return M
