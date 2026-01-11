local M = {}

M.SEED = vim.env.SEED or tostring(os.time())

local function hash_string(str)
  local h = 2166136261
  for i = 1, #str do
    h = bit.bxor(h, str:byte(i))
    h = (h * 16777619) % 2 ^ 32
  end
  return h
end

local function make_rng(seed)
  local state = hash_string(seed)

  return function(min, max)
    state = (1103515245 * state + 12345) % 2 ^ 31
    local r = state / 2 ^ 31
    if min and max then return math.floor(min + r * (max - min + 1)) end
    return r
  end
end

local rng = make_rng(M.SEED)

M.Name = {}
M.Name.__index = M.Name

---@param opts table?
---@return table
function M.Name.new(opts)
  opts = opts or {}

  local self = setmetatable({}, M.Name)
  self.length = opts.length or 5
  self.charset = opts.charset
    or {
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z",
    }

  return self
end

---@return string
function M.Name:generate()
  local out = {}

  for _ = 1, self.length do
    local i = rng(1, #self.charset)
    out[#out + 1] = self.charset[i]
  end

  return table.concat(out)
end

setmetatable(M.Name, {
  __call = function(_, opts) return M.Name.new(opts) end,
})

return M
