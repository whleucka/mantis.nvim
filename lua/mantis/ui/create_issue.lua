local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local function _render_form(props)
  local category_options = {}
  for _,category in ipairs(props.project.categories) do
    table.insert(category_options, n.option(category.name, { id = category.name }))
  end

  local user_options = {}
  for _,user in ipairs(props.users) do
    table.insert(user_options, n.option(user.name, { id = user.name }))
  end

  local signal   = n.create_signal({
    summary = nil,
    description = nil,
    category = props.project.categories[1].name,
    user = props.users[1].name,
  })

  local renderer = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  renderer:render(n.form({
      id = "create-issue",
      submit_key = "<C-CR>",
      on_mount = function(component)
        component:set_border_text("bottom", "[h]elp", "left")
      end,
      on_submit = function(is_valid)
        if is_valid then
          local s = signal:get_value()
          local new_issue = {
            summary = s.summary,
            description = s.description,
            handler = {
              name = s.user
            },
            category = {
              name = s.category,
            },
            project = {
              id = props.project.id
            }
          }
          props.on_submit(new_issue)
        end
      end,
    },
    n.columns(
      { flex = 0 },
      n.select({
        flex = 1,
        border_label = "Category",
        data = category_options,
        multiselect = false,
        on_change = function(node)
          signal.category = node.id
        end,
      }),
      n.select({
        flex = 1,
        border_label = "User",
        data = user_options,
        multiselect = false,
        on_change = function(node)
          signal.user = node.id
        end,
      })
    ),
    n.text_input({
      autofocus = true,
      autoresize = true,
      size = 1,
      border_label = "Summary",
      max_lines = 1,
      validate = n.validator.compose(n.validator.min_length(1), n.validator.max_length(255)),
      on_change = function(value, component)
        signal.summary = value
      end
    }),
    n.text_input({
      flex = 1,
      border_label = "Description",
      max_lines = 5,
      validate = n.validator.compose(n.validator.min_length(1)),
      on_change = function(value, component)
        signal.description = value
      end
    })
  ))
end

function M.render(props)
  _render_form(props)
end

return M
