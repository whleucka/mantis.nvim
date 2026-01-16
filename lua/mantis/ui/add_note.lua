local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local function _render_form(props)
  local signal   = n.create_signal({
    text = nil,
  })

  local renderer = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  renderer:render(n.form({
      id = "add-note",
      autofocus = true,
      submit_key = "<C-CR>",
      on_submit = function(is_valid)
        if is_valid then
          local s = signal:get_value()
          local note = {
            text = s.text,
            view_state = {
              name = "public"
            }
          }
          props.on_submit(note, props.issue_id)
          renderer:close()
        end
      end,
    },
    n.columns(
      { flex = 0 },
      n.text_input({
        flex = 1,
        border_label = "Note",
        size = 3,
        on_change = function(value, component)
          signal.text = value
        end,
        validate = n.validator.compose(n.validator.min_length(1)),
      })
    )
  ))
end

function M.render(props)
  _render_form(props)
end

return M
