local M = {}
local n = require("nui-components")
local config = require("mantis.config")

function M.render(opts)
  local signal       = n.create_signal({
    category = "",
    reproducibility = { id = 70 },
    severity = { id = 50 },
    priority = { id = 30 },
    assigned_to = "",
    summary = "",
    description = "",
  })

  local TOTAL_WIDTH  = config.options.new_issue.ui.width
  local TOTAL_HEIGHT = config.options.new_issue.ui.height

  local renderer     = n.create_renderer({
    width = TOTAL_WIDTH,
    height = TOTAL_HEIGHT,
  })

  -- layout
  local body         = function()
    return n.form(
      {
        id = "new-issue",
        submit_key = "<C-CR>",
        on_submit = function(is_valid)
          if is_valid then
            local data = signal:get_value()
            opts.on_create_issue(data)
          end
        end
      },
      n.columns(
        { flex = 0 },
        n.select({
          autofocus = true,
          flex = 1,
          border_label = "Category",
          selected = signal.category,
          data = {
            n.option("null", { id = 0 })
          },
          multiselect = false,
          on_change = function(category)
            signal.category = category
          end
        }),
        n.select({
          flex = 1,
          border_label = "Reproducibility",
          selected = signal.reproducibility,
          data = {
            n.option("always", { id = 10 }),
            n.option("sometimes", { id = 30 }),
            n.option("random", { id = 50 }),
            n.option("have not tried", { id = 70 }),
            n.option("unable to reproduce", { id = 90 }),
            n.option("N/A", { id = 100 })
          },
          multiselect = false,
          on_change = function(category)
            signal.reproducibility = category
          end
        }),
        n.select({
          flex = 1,
          border_label = "Severity",
          selected = signal.severity,
          data = {
            n.option("feature", { id = 10 }),
            n.option("trivial", { id = 20 }),
            n.option("text", { id = 30 }),
            n.option("tweak", { id = 40 }),
            n.option("minor", { id = 50 }),
            n.option("major", { id = 60 }),
            n.option("crash", { id = 70 }),
            n.option("block", { id = 80 })
          },
          multiselect = false,
          on_change = function(category)
            signal.severity = category
          end
        }),
        n.select({
          flex = 1,
          border_label = "Priority",
          selected = signal.priority,
          data = {
            n.option("none", { id = 10 }),
            n.option("low", { id = 20 }),
            n.option("normal", { id = 30 }),
            n.option("high", { id = 40 }),
            n.option("urgent", { id = 50 }),
            n.option("immediate", { id = 60 }),
          },
          multiselect = false,
          on_change = function(category)
            signal.priority = category
          end
        }),
        n.select({
          flex = 1,
          border_label = "Assigned",
          selected = signal.assigned,
          data = {
            n.option("null", { id = 0 })
          },
          multiselect = false,
          on_change = function(category)
            signal.assigned = category
          end
        })
      ),
      n.text_input({
        autofocus = false,
        autoresize = true,
        border_label = "Summary",
        max_lines = 1,
        validate = n.validator.max_length(255),
        on_change = function(summary)
          signal.summary = summary
        end
      }),
      n.text_input({
        flex = 1,
        max_lines = 10,
        border_label = "Description",
        on_change = function(description)
          signal.description = description
        end
      })
    )
  end

  renderer:render(body)
end

return M
