local M = {}

function M.truncate(str, width)
  if #str <= width then return str end
  return str:sub(1, width - 1) .. "…"
end

function M.print(o)
  print(vim.inspect(o))
end

local timezone_offset = (function()
  local now = os.time()
  local local_t = os.date("*t", now)
  local utc_t = os.date("!*t", now)
  local_t.isdst = false
  return os.difftime(os.time(local_t), os.time(utc_t))
end)()

local function parse_iso8601(ts)
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
  }) + timezone_offset
end

function M.time_ago(ts)
  if not ts then return "?" end
  local epoch = parse_iso8601(ts)

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
