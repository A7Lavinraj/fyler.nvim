local log = require("fyler.log")
local util = require("fyler.lib.util")

local M = {}

local function trace_error(message, co)
  local trace = debug.traceback(co or nil)
  local full_error = string.format("%s\n%s", message, trace)
  log.error(full_error)
  return full_error
end

local function execute_async(async_fn, next, ...)
  local co = coroutine.create(async_fn)
  local args = { ... }

  local function step(...)
    local success, result = coroutine.resume(co, ...)

    if not success then
      trace_error("Coroutine error: " .. tostring(result), co)
      if next then next(nil, result) end
      return
    end

    local status = coroutine.status(co)

    if status == "dead" then
      if next then next(result) end
    elseif status == "suspended" then
      if type(result) == "function" then
        local exec_success, exec_error = pcall(result, step)
        if not exec_success then
          trace_error("Error executing yielded function: " .. tostring(exec_error), co)
          if next then next(nil, exec_error) end
        end
      else
        local error_msg = "Invalid yield: expected function, got " .. type(result)
        trace_error(error_msg, co)
        if next then next(nil, error_msg) end
      end
    end
  end

  local start_success, start_error = pcall(step, util.unpack(args))
  if not start_success then
    trace_error("Failed to start execution: " .. tostring(start_error))
    if next then next(nil, start_error) end
  end
end

function M.await(fn, ...)
  local args = { ... }

  return coroutine.yield(function(resume_fn)
    table.insert(args, function(...)
      local success, error = pcall(resume_fn, ...)
      if not success then trace_error("Error in await callback: " .. tostring(error)) end
    end)

    local success, error = pcall(fn, util.unpack(args))
    if not success then
      trace_error("Error calling awaited function: " .. tostring(error))
      resume_fn(nil, error)
    end
  end)
end

function M.wrap(fn)
  return function(...)
    local args = { ... }

    return M.await(function(cb)
      table.insert(args, cb)
      execute_async(fn, nil, util.unpack(args))
    end)
  end
end

function M.void_wrap(async_fn)
  return function(...) execute_async(async_fn, nil, ...) end
end

function M.void(async_fn, cb) execute_async(async_fn, cb) end

M.schedule = M.wrap(vim.schedule)

setmetatable(M, {
  __index = function(_, k)
    local _, module = pcall(require, "fyler.lib.async." .. k)
    if not module then
      require("fyler.log").error(string.format("Module '%s' is not implemented", k))
    else
      return module
    end
  end,
})

return M
