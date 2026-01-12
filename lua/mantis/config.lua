local M = {}

M.options = {
  debug = false,
  hosts = {},
  selector = {
    ui = {
      width = 50,
      height = 10,
    }
  },
  view_issues = {
    ui = {
      width = 120,
      height = 15,
    },
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
