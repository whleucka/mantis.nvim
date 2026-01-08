local M = {}
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")

function M.render(opts)
  local TOTAL_WIDTH  = config.options.view_issues.ui.width
  local TOTAL_HEIGHT = config.options.view_issues.ui.height
  local COL_ID       = 10
  local COL_COLOR    = 1
  local COL_STATUS   = math.floor((TOTAL_WIDTH + 10) * 0.15)
  local COL_CONTEXT  = math.floor((TOTAL_WIDTH + 10) * 0.18)
  local COL_SUMMARY  = math.floor((TOTAL_WIDTH + 10) * 0.3)
  local COL_CREATED  = math.floor((TOTAL_WIDTH) * 0.1)
  local COL_UPDATED  = math.floor((TOTAL_WIDTH) * 0.1)

  local signal       = n.create_signal({
    value = "",
    issue = nil
  })

  local renderer     = n.create_renderer({
    width = TOTAL_WIDTH,
    height = TOTAL_HEIGHT,
    border_label = "Issues",
  })

  local lines   = {}
  for _, issue in ipairs(opts.issues) do
    -- status hl
    local status_hl_group = "MantisStatus_" .. issue.status.label
    vim.api.nvim_set_hl(0, status_hl_group, { bg = issue.status.color, fg = "#000000" })

    -- format values
    local status  = util.truncate(issue.status.label .. ' (' .. issue.handler.name .. ')', COL_STATUS)
    local context = util.truncate('[' .. issue.project.name .. '] ' .. issue.category.name, COL_CONTEXT)
    local summary = util.truncate(issue.summary, COL_SUMMARY)
    local created = util.time_ago(util.parse_iso8601(issue.created_at))
    local updated = util.time_ago(util.parse_iso8601(issue.updated_at))

    table.insert(lines, n.line(
      n.text(string.format("%-" .. COL_ID .. "s ", string.format("%07d", issue.id))),
      n.text(string.format("%-" .. COL_COLOR .. "s ", ""), status_hl_group),
      n.text(string.format(" %-" .. COL_STATUS .. "s ", status)),
      n.text(string.format(" %-" .. COL_CONTEXT .. "s ", context)),
      n.text(string.format(" %-" .. COL_SUMMARY .. "s ", summary)),
      n.text(string.format(" %-" .. COL_CREATED .. "s ", created), "Comment"),
      n.text(string.format(" %-" .. COL_UPDATED .. "s", updated), "Comment")
    ))
  end

  -- issue rows
  local para = n.paragraph({
    border_label = "View Issues",
    autofocus = true,
    max_lines = 50,
    lines = lines
  })

  -- layout
  local body = function()
    return n.box(
      { flex = 1, direction = "column" },
      n.box(
        { flex = 1, direction = "column" },
        para
      )
    )
  end

  renderer:render(body)
end

return M
