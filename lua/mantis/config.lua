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
      height = 22,
    },
    keymap = {
      open_issue_in_browser = "gx",
      assign_issue_to_user = "ga",
      change_status = "gs",
      quit = "q",
    }
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
