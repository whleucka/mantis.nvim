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
    limit = 20,
    ui = {
      width = 150,
      height = 50,
      column_width = {
        s_color = "%1s ",
        id = "%07d ",
        severity = "%-9s ",
        status = "%-24s",
        category = "%-12s ",
        summary = "%-70s ",
        updated = "%10s"
      }
    },
    keymap = {
      refresh = "gr",
      next_page = "gn",
      prev_page = "gp",
      open_issue = "gx",
      assign_issue = "ga",
      change_status = "gs",
      quit = "q",
    }
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
