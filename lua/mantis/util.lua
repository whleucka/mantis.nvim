local M = {}

--- Truncate a string to a maximum width with ellipsis
---@param str string The string to truncate
---@param width number Maximum width
---@return string
function M.truncate(str, width)
  if type(str) ~= "string" then
    str = tostring(str)
  end
  if #str <= width then return str end
  return str:sub(1, width - 1) .. "…"
end

--- Debug print helper
---@param o any Object to print
function M.print(o)
  print(vim.inspect(o))
end

-- Timezone offset calculated once at module load
local timezone_offset = (function()
  local now = os.time()
  local local_t = os.date("*t", now)
  local utc_t = os.date("!*t", now)
  local_t.isdst = false
  return os.difftime(os.time(local_t), os.time(utc_t))
end)()

--- Parse an ISO8601 timestamp to epoch seconds
---@param ts string ISO8601 timestamp (e.g., "2024-01-15T10:30:00-05:00")
---@return number|nil epoch Epoch seconds or nil if parsing fails
function M.parse_iso8601(ts)
  if not ts then return nil end
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

--- Show a loading message and force redraw
---@param message string The loading message to display
function M.loading(message)
  vim.api.nvim_echo({{ message .. "...", "Comment" }}, false, {})
  vim.cmd('redraw')
end

--- Clear the command line (remove loading message)
function M.loading_done()
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd('redraw')
end

--- Execute a function with a loading indicator
---@param message string The loading message to display
---@param fn function The function to execute
---@return any ... Returns whatever the function returns
function M.with_loading(message, fn)
  M.loading(message)
  local results = { pcall(fn) }
  M.loading_done()
  local ok = table.remove(results, 1)
  if not ok then
    error(results[1])
  end
  return unpack(results)
end

return M
