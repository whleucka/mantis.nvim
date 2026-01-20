local M = {}

function M.validate_time(time_str)
  if not time_str then
    return false, nil
  end

  local hours, minutes
  if time_str:match("^%d%d:%d%d$") then
    hours, minutes = time_str:match("^(%d%d):(%d%d)$")
  else
    return false, nil
  end

  hours = tonumber(hours)
  minutes = tonumber(minutes)

  if hours > 23 or minutes > 59 then
    return false, nil
  end

  return true, string.format("%02d:%02d", hours, minutes)
end

return M