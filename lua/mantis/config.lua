local M = {}

M.options = {
  debug = false,
  hosts = {},
  add_note = {
    ui = {
      width = 60,
      height = 10,
      max_width = 80,
      max_height = 20,
    },
    keymap = {
      quit = "q",
      submit = "<C-CR>",
    }
  },
  create_issue = {
    ui = {
      width = 80,
      height = 21,
      max_width = 120,
      max_height = 30,
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
      max_width = 120,
      max_height = 40,
    },
    keymap = {
      quit = "q",
      refresh = "r",
      add_note = "N",
      scroll_down = "j",
      scroll_up = "k",
      page_down = "<C-d>",
      page_up = "<C-u>",
      goto_top = "gg",
      goto_bottom = "G",
    }
  },
  view_issues = {
    default_filter = 'all', -- default filter: 'all', 'assigned', 'reported', 'monitored', 'unassigned'
    limit = 42, -- issues per page
    ui = {
      -- window size (supports percentages like "90%" or absolute numbers)
      width = "90%",
      height = "80%",
      max_width = 200,
      max_height = 50,
      -- column widths (summary is calculated dynamically to fill remaining space)
      columns = {
        priority = 1,
        id = 7,
        severity = 10,
        status = 24,
        category = 12,
        summary = nil, -- auto-calculated based on available width
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
      -- Selection
      toggle_select = "<Space>",
      select_all = "<C-a>",
      clear_selection = "<C-x>",
      -- Batch operations
      batch_status = "bs",
      batch_priority = "bp",
      batch_severity = "bv",
      batch_category = "bc",
      batch_assign = "ba",
      batch_delete = "bD",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
  issue_resolution_options = {},
  issue_reproducibility_options = {},
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
