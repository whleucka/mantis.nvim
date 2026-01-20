local M = {}

function M.is_valid_time(str)
  if not str then return true end

  local h, m, s = str:match("^(%d%d):(%d%d):?(%d*)$")

  if not h then
    return false
  end

  h, m = tonumber(h), tonumber(m)
  s = s ~= "" and tonumber(s) or nil

  if h > 23 or m > 59 then
    return false
  end

  if s and s > 59 then
    return false
  end

  return true
end

return M
