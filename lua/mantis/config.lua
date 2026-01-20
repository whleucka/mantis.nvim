local M = {}

M.options = {
  debug = false,
  hosts = {},
  add_note = {
    ui = {
      width = 80,
      height = 15,
    },
    keymap = {
      quit = "q",
      submit = "<C-CR>",
    }
  },
  create_issue = {
    ui = {
      width = 80,
      height = 15,
    },
    keymap = {
      quit = "q",
      submit = "<C-CR>",
    }
  },
  view_issue = {
    ui = {
      width = 80,
      height = 30,
    },
    keymap = {
      quit = "q",
    }
  },
  view_issues = {
    limit = 40,
    ui = {
      width = 150,
      height = 50,
      columns = {
        priority = 1,
        id = 7,
        severity = 10,
        status = 24,
        category = 12,
        summary = 69,
        updated = 10
      }
    },
    keymap = {
      next_page = "L",
      prev_page = "H",
      add_note = "N",
      create_issue = "C",
      delete_issue = "D",
      open_issue = "o",
      assign_issue = "a",
      change_summary = "S",
      change_status = "s",
      change_severity = "v",
      change_priority = "p",
      change_category = "c",
      filter = "f",
      help = "?",
      refresh = "r",
      quit = "q",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
  issue_resolution_options = {
    { id = 10, name = 'open' },
    { id = 20, name = 'fixed' },
    { id = 30, name = 'reopened' },
    { id = 40, name = 'unable to reproduce' },
    { id = 50, name = 'not fixable' },
    { id = 60, name = 'duplicate' },
    { id = 70, name = 'no change required' },
    { id = 80, name = 'suspended' },
    { id = 90, name = "won't fix" },
  },
  issue_filter_options = {
    'all',
    'assigned',
    'reported',
    'monitored',
    'unassigned',
  },
  priority_emojis = {
    complete = "✅",
    immediate = "🔥",
    urgent    = "‼️",
    high      = "🔺",
    normal    = "🟦",
    low       = "🔻",
    default   = "❓"
  },
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
