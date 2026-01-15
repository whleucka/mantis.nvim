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
  create_issue = {
    ui = {
      width = 80,
      height = 15,
    }
  },
  view_issues = {
    limit = 24,
    ui = {
      width = 150,
      height = 34,
      column_width = {
        s_color = 1,
        id = 7,
        severity = 9,
        status = 24,
        category = 12,
        summary = 70,
        updated = 10
      }
    },
    keymap = {
      next_page = "<C-n>",
      prev_page = "<C-p>",
      create_issue = "gc",
      open_issue = "gx",
      assign_issue = "ga",
      change_status = "gs",
      refresh = "gr",
      quit = "q",
    }
  }
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
