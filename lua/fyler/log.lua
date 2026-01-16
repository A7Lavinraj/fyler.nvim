local M = {}

---@param message string
---@param level integer
local __log = vim.schedule_wrap(function(message, level) vim.notify(message, level, { title = " [Fyler.nvim] " }) end)

---@param message string
function M.info(message) __log(message, vim.log.levels.INFO) end

---@param message string
function M.warn(message) __log(message, vim.log.levels.WARN) end

---@param message string
function M.error(message) __log(message, vim.log.levels.ERROR) end

return M
