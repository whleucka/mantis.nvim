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

function M.truncate(str, width)
  if #str <= width then return str end
  return str:sub(1, width - 1) .. "…"
end

function M.parse_iso8601(ts)
  -- strip timezone, assume UTC
  local date, time = ts:match("^(%d+-%d+-%d+)T(%d+:%d+:%d+)")
  if not date or not time then
    return nil
  end

  local y, m, d = date:match("(%d+)-(%d+)-(%d+)")
  local hh, mm, ss = time:match("(%d+):(%d+):(%d+)")

  return os.time({
    year  = tonumber(y),
    month = tonumber(m),
    day   = tonumber(d),
    hour  = tonumber(hh),
    min   = tonumber(mm),
    sec   = tonumber(ss),
    isdst = false,
  })
end

function M.time_ago(epoch)
  if not epoch then return "?" end

  local diff = os.time() - epoch

  if diff < 60 then
    return diff .. "s ago"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h ago"
  elseif diff < 604800 then
    return math.floor(diff / 86400) .. "d ago"
  else
    return math.floor(diff / 604800) .. "w ago"
  end
end

return M
