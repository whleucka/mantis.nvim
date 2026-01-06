local M = {}

-- From https://gist.github.com/dexpota/24f11a2579b2a52331525180016a2441
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

function M.hex_to_rgb(hex)
  local r = tonumber("0x" .. hex:sub(2, 3))
  local g = tonumber("0x" .. hex:sub(4, 5))
  local b = tonumber("0x" .. hex:sub(6, 7))
  return r, g, b
end

function M.get_luminance(r, g, b)
  local r_lin = r / 255
  local g_lin = g / 255
  local b_lin = b / 255

  r_lin = (r_lin <= 0.03928) and (r_lin / 12.92) or ((r_lin + 0.055) / 1.055) ^ 2.4
  g_lin = (g_lin <= 0.03928) and (g_lin / 12.92) or ((g_lin + 0.055) / 1.055) ^ 2.4
  b_lin = (b_lin <= 0.03928) and (b_lin / 12.92) or ((b_lin + 0.055) / 1.055) ^ 2.4

  return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin
end

return M
