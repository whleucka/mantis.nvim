local M = {}
local n = require("nui-components")
local util = require("mantis.util")

function M.render(opts)
  local TOTAL_WIDTH   = 150
  local CONTENT_WIDTH = TOTAL_WIDTH - 4

  local COL_ID        = 15
  local COL_STATUS    = 25
  local COL_PRIORITY  = 15
  local COL_SEVERITY  = 15
  local COL_CREATED   = 15
  local COL_UPDATED   = 15

  local SUMMARY_WIDTH =
      CONTENT_WIDTH
      - COL_ID
      - COL_STATUS
      - COL_PRIORITY
      - COL_SEVERITY
      - COL_CREATED
      - COL_UPDATED

  local header_fmt    = string.format(
    "%%-%ds %%-%ds %%-%ds %%-%ds %%-%ds %%-%ds %%-%ds",
    COL_ID,
    COL_STATUS,
    COL_PRIORITY,
    COL_SEVERITY,
    SUMMARY_WIDTH,
    COL_CREATED,
    COL_UPDATED
  )

  local lines         = {}
  local row_fmt       = header_fmt

  local signal        = n.create_signal({
    value = "",
    issue = nil
  })

  local renderer      = n.create_renderer({
    width = TOTAL_WIDTH,
    height = 50,
    border_label = "Issues",
  })

  table.insert(lines,
    n.line(string.format(
      header_fmt,
      "ID", "STATUS", "PRIORITY", "SEVERITY", "SUMMARY", "CREATED", "UPDATED"
    ))
  )

  for _, issue in ipairs(opts.issues) do
    local created = util.time_ago(util.parse_iso8601(issue.created_at))
    local updated = util.time_ago(util.parse_iso8601(issue.updated_at))
    table.insert(lines,
      n.line(string.format(
        row_fmt,
        tostring(issue.id),
        issue.status.label .. ' (' .. issue.handler.name .. ')',
        issue.priority.label,
        issue.severity.label,
        util.truncate(issue.summary, SUMMARY_WIDTH),
        created,
        updated
      ))
    )
  end

  -- search input
  local search = n.text_input({
    border_label = "Search",
    placeholder = "...",
    autofocus = false,
    autoresize = true,
    size = 1,
    value = signal.value,
    max_lines = 1,
    on_change = function(value, component)
      signal.value = value
    end,
  })

  -- issue rows
  local para = n.paragraph({
    border_label = "Issues",
    autofocus = true,
    max_lines = 20,
    lines = lines
  })

  -- layout
  local body = function()
    return n.box(
      {
        flex = 1,
        direction = "column"
      },
      search,
      n.box(
        {
          flex = 1,
          direction = "column",
        },
        para
      )
    )
  end

  renderer:render(body)
end

return M
