local M = {}
local n = require("nui-components")

function M.render(opts)
  local hosts = opts.hosts
  local on_submit = opts.on_submit

  -- build select options
  local options = {}
  for name, _ in pairs(hosts) do
    table.insert(options, n.option(name, { id = name }))
  end

  -- default selection = first host key
  local default = next(hosts)
  local signal = n.create_signal({
    selected = default, -- string ID of host
  })

  -- window
  local renderer = n.create_renderer({
    width = 50,
    height = 10,
  })

  -- define select
  local select = n.select({
    border_label = "Select Mantis Host",
    selected = signal.selected,
    data = options,
    multiselect = false,
    on_change = function(node)
      signal.selected = node.id
    end,
  })

  -- define button
  local button = n.button({
    label = "View Issues",
    on_press = function()
      -- get value from SignalValue
      local host_key = signal.selected:get_value()
      if on_submit then
        on_submit(host_key)
      end
      renderer:close()
    end,
  })

  -- layout
  local body = function()
    return n.rows(
      select,
      button
    )
  end

  -- render
  renderer:render(body)

-- autofocus the select
  vim.schedule(function()
    select:focus()
  end)
end

return M
