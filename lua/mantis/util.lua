-- Mantis.nvim Utilities
local M = {}

-- Taken from https://gist.github.com/dexpota/24f11a2579b2a52331525180016a2441
function M.hex_to_cterm(hex)
  local hex = hex:gsub("#", "")
  local r = tonumber("0x" .. hex:sub(1, 2)) / 255
  local g = tonumber("0x" .. hex:sub(3, 4)) / 255
  local b = tonumber("0x" .. hex:sub(5, 6)) / 255

  local r_ansi = math.floor(r * 5)
  local g_ansi = math.floor(g * 5)
  local b_ansi = math.floor(b * 5)

  return 16 + (r_ansi * 36) + (g_ansi * 6) + b_ansi
end

return M
