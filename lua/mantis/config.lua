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
      refresh = "r",
      scroll_down = "j",
      scroll_up = "k",
      page_down = "<C-d>",
      page_up = "<C-u>",
      goto_top = "gg",
      goto_bottom = "G",
    }
  },
  view_issues = {
    limit = 42, -- issues per page
    ui = {
      -- column width
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
      toggle_group = "g",
      help = "?",
      refresh = "r",
      quit = "q",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
  issue_resolution_options = {},
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
    urgent    = "⚠️",
    high      = "🔺",
    low       = "🔻",
    normal    = "🔵",
    default   = "🟣" -- if no priority is set
  },
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

return M
