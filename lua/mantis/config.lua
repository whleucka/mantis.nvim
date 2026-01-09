local M = {}

M.options = {
  debug = false,
  hosts = {},
  new_issue = {
    ui = {
      width = 90,
      height = 20,
    },
  },
  view_issue = {
    ui = {
      width = 150,
      height = 20,
    },
  },
  view_issues = {
    page_size = 50,
    ui = {
      width = 150,
      height = 80,
    },
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
