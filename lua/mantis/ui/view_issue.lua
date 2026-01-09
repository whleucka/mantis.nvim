local M = {}
local n = require("nui-components")
local config = require("mantis.config")

function M.render(opts)
  -- local signal       = n.create_signal({
  --   value = "",
  --   issue = nil
  -- })

  local TOTAL_WIDTH  = config.options.view_issue.ui.width
  local TOTAL_HEIGHT = config.options.view_issue.ui.height

  local renderer     = n.create_renderer({
    width = TOTAL_WIDTH,
    height = TOTAL_HEIGHT,
  })

  local id           = n.text_input({
    autofocus = false,
    autoresize = false,
    size = 5,
    value = tostring(opts.issue.id),
    border_label = "ID",
    max_lines = 1
  })
  local project      = n.text_input({
    autofocus = false,
    autoresize = false,
    size = 5,
    value = tostring(opts.issue.project.name),
    border_label = "Project",
    max_lines = 1
  })
  local summary      = n.text_input({
    autofocus = true,
    autoresize = true,
    size = 1,
    value = tostring(opts.issue.summary),
    border_label = "Description",
    placeholder = "Enter a description",
    max_lines = 5
  })

  -- quit
  local btn_quit     = n.button({
    label = "Quit",
    global_press_key = "q",
    on_press = function()
      renderer:close()
    end,
  })

  -- layout
  local body         = function()
    return n.box(
      { flex = 0, direction = "column" },
      n.columns(
        { flex = 0, size = 6 },
        id, project
      ),
      n.box(
        { flex = 1, direction = "column" },
        summary
      )
    )
  end

  renderer:render(body)
end

return M
