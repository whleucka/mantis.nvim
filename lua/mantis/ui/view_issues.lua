local M = {}
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")

function M.render(opts)
  local TOTAL_WIDTH  = config.options.view_issues.ui.width
  local TOTAL_HEIGHT = config.options.view_issues.ui.height
  local COL_ID       = 10
  local COL_STATUS   = math.floor((TOTAL_WIDTH + 15) * 0.15)
  local COL_CONTEXT  = math.floor((TOTAL_WIDTH + 15) * 0.18)
  local COL_SUMMARY  = math.floor((TOTAL_WIDTH + 20) * 0.3)
  local COL_CREATED  = math.floor((TOTAL_WIDTH) * 0.1)
  local COL_UPDATED  = math.floor((TOTAL_WIDTH) * 0.1)

  local signal       = n.create_signal({
    value = "",
    issue = nil
  })

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
      n.text(string.format(" %-" .. COL_CONTEXT .. "s ", context), "Constant"),
      n.text(string.format(" %-" .. COL_SUMMARY .. "s ", summary)),
      n.text(string.format(" %-" .. COL_CREATED .. "s ", created), "Comment"),
      n.text(string.format(" %-" .. COL_UPDATED .. "s", updated), "Comment")
    ))
  end

  -- issue rows
  local para = n.paragraph({
    border_label = string.format("Mantis Issues [%s]", opts.host),
    autofocus = true,
    max_lines = TOTAL_HEIGHT,
    lines = lines
  })

  -- view toggles
  local all_issues = n.button({
    label = "View All Issues",
    global_press_key = "v",
    on_press = function()
      opts.on_view_issues()
      renderer:close()
    end,
  })

  local assigned_issues = n.button({
    label = "View Assigned Issues",
    global_press_key = "v",
    on_press = function()
      opts.on_assigned_issues()
      renderer:close()
    end,
  })

  local btn_view = (opts.assigned and all_issues) or assigned_issues

  local btn_assign_user = n.button({
    label = "Assign User",
    global_press_key = "a",
    on_press = function()
      print("WIP: assign user")
    end,
  })

  local btn_change_status = n.button({
    label = "Change Status",
    global_press_key = "s",
    on_press = function()
      print("WIP: change status")
    end,
  })

  -- quit
  local btn_quit = n.button({
    label = "Quit",
    global_press_key = "q",
    on_press = function()
      renderer:close()
    end,
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
        { flex = 0, direction = "row" },
        btn_view, btn_assign_user, btn_change_status, btn_quit
      )
    )
  end

  renderer:render(body)
end

return M
