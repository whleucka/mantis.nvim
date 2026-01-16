local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local function _is_valid_time(str)
  if not str then return true end

  local h, m, s = str:match("^(%d%d):(%d%d):?(%d*)$")

  if not h then
    return false
  end

  h, m = tonumber(h), tonumber(m)
  s = s ~= "" and tonumber(s) or nil

  if h > 23 or m > 59 then
    return false
  end

  if s and s > 59 then
    return false
  end

  return true
end


local function _render_form(props)
  local signal   = n.create_signal({
    text = nil,
    time = nil,
    show_time = false,
  })

  local renderer = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  renderer:render(n.form({
      id = "add-note",
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
          local time = signal.time:get_value()
          if time ~= nil then
            note.time_tracking = {}
            note.time_tracking.duration = time
          end
          props.on_submit(note, props.issue_id)
          renderer:close()
        end
      end,
    },
    n.rows(
      { flex = 1 },
      n.text_input({
        flex = 1,
        autofocus = true,
        border_label = "Note",
        size = 1,
        max_lines = 3,
        on_change = function(value, component)
          signal.text = value
        end,
        validate = n.validator.compose(n.validator.min_length(1)),
        on_focus = function()
          local keymap = props.options.keymap

          -- toggle time tracking
          vim.keymap.set("n", keymap.toggle_time, function()
            local show_time = signal.show_time:get_value()
            signal.show_time = not show_time
          end, { desc = "Toggle Time Tracking", buffer = true })
        end,
      }),
      n.text_input({
        placeholder = "hh:mm:ss",
        flex = 1,
        hidden = signal.show_time:negate(),
        max_lines = 1,
        border_label = "Time Tracking",
        on_change = function(value, component)
          signal.time = value
        end,
        validate = n.validator.compose(function()
          return _is_valid_time(signal.time:get_value())
        end),
      })
    )
  ))
end

function M.render(props)
  _render_form(props)
end

return M
