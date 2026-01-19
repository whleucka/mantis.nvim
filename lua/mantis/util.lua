local M = {}

function M.truncate(str, width)
  if #str <= width then return str end
  return str:sub(1, width - 1) .. "…"
end

function M.print(o)
  print(vim.inspect(o))
end

return M
