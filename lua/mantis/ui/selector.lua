local M = {}
local n = require("nui-components")

function M.render(props)
  local options = {}
  for name, _ in pairs(props.items) do
    table.insert(options, n.option(name, { id = name }))
  end

  local default = next(props.items)
  local signal = n.create_signal({
    selected = default,
  })

  -- window
  local renderer = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  local select = n.select({
    border_label = props.title,
    selected = signal.selected,
    data = options,
    multiselect = false,
    on_change = function(node)
      signal.selected = node.id
    end,
    on_select = function(node)
      props.on_submit(node.id)
      renderer:close()
    end
  })

  local body = function()
    return n.rows(
      select
    )
  end

  renderer:render(body)

  vim.schedule(function()
    select:focus()
  end)
end

return M
