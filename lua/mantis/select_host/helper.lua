local M = {}

function M.parse_enum_table(enum_table)
  local options = {}
  if type(enum_table) ~= "table" then
    return options
  end
  for _, item in ipairs(enum_table) do
    if type(item) == "table" and item.name then
      table.insert(options, item.name)
    end
  end
  return options
end

return M
