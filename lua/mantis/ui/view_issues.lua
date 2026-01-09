local M = {}
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")

function M.render(opts)
  local signal       = n.create_signal({
    keymaps_hidden = true
  })

  local TOTAL_WIDTH  = config.options.view_issues.ui.width
  local TOTAL_HEIGHT = config.options.view_issues.ui.height
  local COL_ID       = 8
  local COL_STATUS   = math.floor((TOTAL_WIDTH + 15) * 0.15)
  local COL_CONTEXT  = math.floor((TOTAL_WIDTH + 15) * 0.18)
  local COL_SUMMARY  = math.floor((TOTAL_WIDTH + 20) * 0.3)
  local COL_CREATED  = math.floor((TOTAL_WIDTH) * 0.1)
  local COL_UPDATED  = math.floor((TOTAL_WIDTH) * 0.1)

  local renderer     = n.create_renderer({
    width = TOTAL_WIDTH,
    height = TOTAL_HEIGHT,
  })

  local lines        = {}
  for _, issue in ipairs(opts.issues) do
    -- status hl
    local status_hl_group = "MantisStatus_" .. issue.status.label
    vim.api.nvim_set_hl(0, status_hl_group, { bg = issue.status.color, fg = "#222222" })

    -- format values
    local status  = util.truncate(issue.status.label .. ' (' .. issue.handler.name .. ')', COL_STATUS)
    local context = util.truncate('[' .. issue.project.name .. '] ' .. issue.category.name, COL_CONTEXT)
    local summary = util.truncate(issue.summary, COL_SUMMARY)
    local created = util.time_ago(util.parse_iso8601(issue.created_at))
    local updated = util.time_ago(util.parse_iso8601(issue.updated_at))

    table.insert(lines, n.line(
      n.text(string.format("%-" .. COL_ID .. "s ", string.format("%07d", issue.id)), "String"),
      n.text(string.format(" %-" .. COL_STATUS .. "s ", status), status_hl_group),
      n.text(string.format(" %-" .. COL_CONTEXT .. "s ", context), "Keyword"),
      n.text(string.format(" %-" .. COL_SUMMARY .. "s ", summary)),
      n.text(string.format(" %-" .. COL_CREATED .. "s ", created), "Comment"),
      n.text(string.format(" %-" .. COL_UPDATED .. "s", updated), "Comment")
    ))
  end

  -- issue rows
  local para = n.paragraph({
    border_label = string.format("%s Mantis Issues [%s]", (opts.assigned and "Assigned") or "All", opts.host),
    autofocus = true,
    max_lines = TOTAL_HEIGHT,
    lines = lines,
    on_focus = function(state)
      vim.wo[state.winid].cursorline = true

      vim.keymap.set("n", "?", function()
        local setting = not signal.keymaps_hidden
        signal.keymaps_hidden = setting
      end, { buffer = state.bufnr })

      vim.keymap.set("n", "<CR>", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = opts.issues[current_line]
        -- opts.on_view_issue(issue.id)
        -- renderer:close()
      end, { buffer = state.bufnr })

      vim.keymap.set("n", "o", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = opts.issues[current_line]
        local url = opts.url .. '/view.php?id=' .. issue.id
        vim.system({'xdg-open', url}, { detach = true })
      end, { buffer = state.bufnr })
    end
  })

  -- view toggles
  local all_issues = n.button({
    hidden = true,
    label = "All Issues",
    global_press_key = "v",
    on_press = function()
      opts.on_view_issues()
      renderer:close()
    end,
  })

  local assigned_issues = n.button({
    hidden = true,
    label = "Assigned Issues",
    global_press_key = "v",
    on_press = function()
      opts.on_assigned_issues()
      renderer:close()
    end,
  })

  local btn_view = (opts.assigned and all_issues) or assigned_issues

  local btn_assign_user = n.button({
    hidden = true,
    label = "Assign",
    global_press_key = "a",
    on_press = function()
      print("WIP: assign")
    end,
  })

  local btn_change_status = n.button({
    hidden = true,
    label = "Status",
    global_press_key = "s",
    on_press = function()
      print("WIP: status")
    end,
  })

  local btn_new_issue = n.button({
    hidden = true,
    label = "New Issue",
    global_press_key = "n",
    on_press = function()
      opts.on_new_issue()
      renderer:close()
    end,
  })

  -- quit
  local btn_quit = n.button({
    hidden = true,
    label = "Quit",
    global_press_key = "q",
    on_press = function()
      renderer:close()
    end,
  })

  -- helper
  local keymaps = {
    "a Assign",
    "s Status",
    "n New",
    "o Open issue in browser",
    "v Toggle view",
    "q Quit",
  }
  local helper = n.paragraph({
    hidden = signal.keymaps_hidden,
    border_label = string.format("Keymaps", opts.host),
    autofocus = false,
    max_lines = 10,
    align = 'center',
    lines = {
      n.line(n.text(table.concat(keymaps, " | "), "Comment"))
    }
  })

  -- layout
  local body = function()
    return n.box(
      { flex = 1, direction = "column" },
      n.box(
        { flex = 0, direction = "column" },
        para
      ),
      n.box(
        { flex = 0, direction = "column" },
        helper
      ),
      n.box(
        { flex = 0, direction = "row" },
        btn_new_issue, btn_view, btn_assign_user, btn_change_status, btn_quit
      )
    )
  end

  renderer:render(body)
end

return M
