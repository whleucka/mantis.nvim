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
      toggle_time = "<C-t>",
    }
  },
  create_issue = {
    ui = {
      width = 80,
      height = 15,
    }
  },
  view_issue = {
    ui = {
      width = 80,
      height = 30,
    }
  },
  view_issues = {
    limit = 42,
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
      add_note = "n",
      create_issue = "c",
      open_issue = "o",
      assign_issue = "a",
      change_status = "s",
      change_severity = "v",
      change_priority = "p",
      help = "?",
      refresh = "r",
      quit = "q",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
  issue_filters = {
    'all',
    'assigned',
    'reported',
    'monitored',
    'unassigned',
  },
  priority_emojis = {
    complete = "✅",
    immediate = "🔥",
    urgent    = "⚠️",
    high      = "🔴",
    normal    = "🟢",
    low       = "🔵",
    default   = "⚪"
  },
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
