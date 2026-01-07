local M = {}
local n = require("nui-components")

function M.render(issues)
  local signal = n.create_signal({
    value = "",
    issue = nil
  })

  local renderer = n.create_renderer({
    width = 150,
    height = 50,
    border_label = "Issues",
  })

  local lines = {}
  table.insert(lines,
    n.line("ID    PRIORITY    SEVERITY    CONTEXT    CREATED    UPDATED"))
  for _, issue in ipairs(issues) do
    table.insert(lines,
      n.line(string.format("%s    %s    %s    %s    %s    %s", tostring(issue.id), issue.priority.label, issue.severity.label,
        issue.summary, issue.created_at, issue.updated_at)))
  end

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

  local para = n.paragraph({
    border_label = "Issues",
    autofocus = true,
    max_lines = 20,
    lines = lines
  })

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
