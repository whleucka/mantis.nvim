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

local function _render_tree(props)
  local signal   = n.create_signal({
    selected = nil,
  })

  local renderer = n.create_renderer({
    width = props.options.ui.width,
    height = props.options.ui.height,
  })

  local tree     = n.tree({
    flex = 1,
    autofocus = true,
    border_label = "MantisBT Issues",
    data = build_nodes(props.issues),
    on_focus = function(state)
      vim.wo[state.winid].cursorline = true

      -- refresh issues view
      vim.keymap.set("n", "r", function()
        props.on_refresh(function()
          renderer:close()
        end)
      end, { buffer = state.bufnr })

      -- issues prev page
      vim.keymap.set("n", "[p", function()
        if props.has_prev_page then
          props.on_prev_page(function()
            renderer:close()
          end)
        end
      end, { buffer = state.bufnr })

      -- issues next page
      vim.keymap.set("n", "]p", function()
        props.on_next_page(function()
          if props.has_next_page then
            renderer:close()
          end
        end)
      end, { buffer = state.bufnr })

      -- open issue in browser
      vim.keymap.set("n", "gx", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = props.issues[current_line]
        local url = string.format("%s/view.php?id=%d", props.host.url, issue.id)
        vim.system({ 'xdg-open', url }, { detach = true })
      end, { buffer = state.bufnr })

      -- assign user
      vim.keymap.set("n", "ga", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = props.issues[current_line]
        props.on_assign_user(issue.id, issue.project.id, function(updated_issue)
          props.issues[current_line] = updated_issue.issues[1]
          renderer:close()
          _render_tree(props)
        end)
      end, { buffer = state.bufnr })

      -- change status
      vim.keymap.set("n", "gs", function()
        local current_line = vim.api.nvim_win_get_cursor(state.winid)[1]
        local issue = props.issues[current_line]
        props.on_change_status(issue.id, function(updated_issue)
          props.issues[current_line] = updated_issue.issues[1]
          renderer:close()
          _render_tree(props)
        end)
      end, { buffer = state.bufnr })

      -- quit with 'q'
      vim.keymap.set("n", "q", function()
        renderer:close()
      end, { buffer = state.bufnr })
    end,
    on_mount = function(component)
      component:set_border_text("bottom", "Page: " .. props.page, "right")
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
  renderer:render(n.rows(tree))
end

function M.render(props)
  _render_tree(props)
end

return M
