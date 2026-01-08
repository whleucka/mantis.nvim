local M = {}

M.options = {
  debug = false,
  hosts = {},
  ui = {
    view_issues = {
      width = 150,
      height = 50,
    }
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
