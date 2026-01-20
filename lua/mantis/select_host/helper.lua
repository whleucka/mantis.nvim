local M = {}

function M.parse_enum_table(enum_table)
  if type(enum_table) == "table" then
    return enum_table
  end
  return {}
end

return M