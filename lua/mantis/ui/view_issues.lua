local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local function build_nodes(issues)
  local nodes = {}
  for _, issue in ipairs(issues) do
    nodes[#nodes + 1] = n.node({ issue = issue })
  end
  return nodes
end

function M.render(props)
  local signal       = n.create_signal({
    selected = nil,
    issues = props.issues,
  })

  local renderer     = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  local tree         = n.tree({
    flex = 1,
    autofocus = true,
    border_label = "MantisBT Issues",
    data = build_nodes(signal.issues:get_value()),
    on_focus = function(state)
      vim.wo[state.winid].cursorline = true
      -- Open issue in browser
      vim.keymap.set("n", "o", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = signal.issues:get_value()[current_line]
        local url = props.host.url .. '/view.php?id=' .. issue.id
        vim.system({ 'xdg-open', url }, { detach = true })
      end, { buffer = state.bufnr })

      vim.keymap.set("n", "s", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = signal.issues:get_value()[current_line]
        props.on_change_status(issue.id, function(updated_issue)
          local issues = vim.deepcopy(signal.issues:get_value())
          issues[current_line] = updated_issue
          -- update trigger
          signal:set_value({ issues = issues })
        end)
      end, { buffer = state.bufnr })

      vim.keymap.set("n", "q", function()
        renderer:close()
      end, { buffer = state.bufnr })
    end,
    on_select = function(node, component)
      signal.selected = node.issue.id
      print(node.issue.id)
    end,
    prepare_node = function(node, line, component)
      local issue = node.issue

      local id = n.text(string.format("%-7s ", string.format("%07d", issue.id)), "Constant")
      line:append(id)

      local severity = n.text(string.format("%-10s ", issue.severity.label), "String")
      line:append(severity)

      local status_hl_group = "MantisStatus_" .. issue.status.label
      vim.api.nvim_set_hl(0, status_hl_group, { bg = issue.status.color, fg = "#222222" })
      local status = n.text(
        string.format("%-23s", issue.status.label .. ' (' .. util.truncate(issue.handler.name, 8) .. ')'),
        status_hl_group)
      line:append(status)

      local project_category = util.truncate("[" .. issue.project.name .. "] " .. issue.category.name, 32)
      local context = n.text(string.format(" %-32s", project_category))
      line:append(context)

      local summary = n.text(string.format(" %-32s", util.truncate(issue.summary, 32)))
      line:append(summary)

      local updated = n.text(string.format(" %-10s", util.time_ago(util.parse_iso8601(issue.updated_at))), "Comment")
      line:append(updated)

      return line
    end,
  })

  local subscription = signal:observe(function(prev, current)
    print("Something changed!")
    renderer:redraw()
  end)

  -- layout
  local body         = n.rows(tree)

  renderer:render(body)

  renderer:on_unmount(function()
    subscription:unsubscribe()
  end)
end

return M
