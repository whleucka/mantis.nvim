-- Mantis.nvim Configuration
local M = {}

M.options = {
  url = nil,
  token = nil,
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

function M.get()
  return M.options
end

return M
