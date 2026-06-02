local M = {}

--- Truncate a string to a maximum display width with ellipsis
---@param str string The string to truncate
---@param width number Maximum display width
---@return string
function M.truncate(str, width)
  if type(str) ~= "string" then
    str = tostring(str)
  end
  if vim.fn.strdisplaywidth(str) <= width then return str end
  -- Trim characters until display width fits (accounts for multi-byte/emoji)
  local chars = vim.fn.strcharlen(str)
  for i = chars - 1, 0, -1 do
    local sub = vim.fn.strcharpart(str, 0, i)
    if vim.fn.strdisplaywidth(sub) <= width - 1 then
      return sub .. "…"
    end
  end
  return "…"
end

--- Debug print helper
---@param o any Object to print
function M.print(o)
  print(vim.inspect(o))
end

--- Convert a UTC date/time to epoch seconds (timezone-independent).
--- Uses Howard Hinnant's days-from-civil algorithm so there is no
--- dependence on the local timezone or DST.
local function utc_to_epoch(y, m, d, hh, mm, ss)
  local yy = (m <= 2) and (y - 1) or y
  local era = math.floor((yy >= 0 and yy or yy - 399) / 400)
  local yoe = yy - era * 400
  local doy = math.floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  local days = era * 146097 + doe - 719468
  return days * 86400 + hh * 3600 + mm * 60 + ss
end

--- Parse an ISO8601 timestamp to epoch seconds.
--- Honors the timezone offset embedded in the string (e.g. "-06:00", "Z",
--- "+00:00") and returns an absolute epoch, so comparisons against os.time()
--- are correct regardless of the machine's local timezone.
---@param ts string ISO8601 timestamp (e.g., "2024-01-15T10:30:00-05:00")
---@return number|nil epoch Epoch seconds or nil if parsing fails
function M.parse_iso8601(ts)
  if not ts then return nil end
  local y, m, d, hh, mm, ss = ts:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return nil
  end

  local epoch = utc_to_epoch(tonumber(y), tonumber(m), tonumber(d),
    tonumber(hh), tonumber(mm), tonumber(ss))

  -- Subtract the offset embedded in the timestamp to get true UTC.
  -- No offset (or trailing "Z") means the value is already UTC.
  local sign, oh, om = ts:match("([+-])(%d%d):?(%d%d)$")
  if sign then
    local off = (tonumber(oh) * 3600 + tonumber(om) * 60) * (sign == "-" and -1 or 1)
    epoch = epoch - off
  end

  return epoch
end

--- Format an ISO8601 timestamp as a human-readable datetime
---@param ts string ISO8601 timestamp
---@return string Formatted datetime (e.g., "2024-01-15 10:30")
function M.format_datetime(ts)
  if not ts then return "N/A" end
  local epoch = M.parse_iso8601(ts)
  if not epoch then return ts end
  return os.date("%Y-%m-%d %H:%M", epoch)
end

--- Format an ISO8601 timestamp as relative time (e.g., "5m ago")
---@param ts string ISO8601 timestamp
---@return string Relative time string
function M.time_ago(ts)
  if not ts then return "?" end
  local epoch = M.parse_iso8601(ts)
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

--- Open a URL in the system's default browser (cross-platform)
---@param url string The URL to open
function M.open_url(url)
  local cmd
  if vim.fn.has('mac') == 1 then
    cmd = { 'open', url }
  elseif vim.fn.has('win32') == 1 then
    cmd = { 'cmd', '/c', 'start', '', url }
  else
    cmd = { 'xdg-open', url }
  end
  vim.system(cmd, { detach = true })
end

--- Execute a function with a loading indicator
---@param message string The loading message to display
---@param fn function The function to execute
---@return any ... Returns whatever the function returns
function M.with_loading(message, fn)
  vim.notify(message .. "...", vim.log.levels.INFO)
  local results = { pcall(fn) }
  local ok = table.remove(results, 1)
  if not ok then
    error(results[1])
  end
  return unpack(results)
end

--- Resolve a dimension value (percentage or absolute) with clamping
---@param value string|number The dimension value ("90%" or 80)
---@param total number The total screen dimension (vim.o.columns or vim.o.lines)
---@param max number|nil Optional maximum value to clamp to
---@param min number|nil Optional minimum value (default 20)
---@return number
function M.resolve_dimension(value, total, max, min)
  min = min or 20
  local result
  if type(value) == "string" and value:match("%%$") then
    local pct = tonumber(value:match("^(%d+)")) or 80
    result = math.floor(total * pct / 100)
  else
    result = tonumber(value) or 80
  end

  -- Clamp to max if specified
  if max and result > max then
    result = max
  end

  -- Ensure minimum size and don't exceed screen
  result = math.max(min, math.min(result, total - 4))

  return result
end

return M
