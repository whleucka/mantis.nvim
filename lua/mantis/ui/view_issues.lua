local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local flat_issues = {}

local function build_nodes(issues)
  local projects = {}

  for _, issue in ipairs(issues) do
    local pid = issue.project.id
    if not projects[pid] then
      projects[pid] = { project = issue.project, issues = {} }
    end
    table.insert(projects[pid].issues, issue)
  end

  local nodes = {}
  for _, entry in pairs(projects) do
    -- sort issues by updated_at
    table.sort(entry.issues, function(a, b)
      return a.updated_at > b.updated_at
    end)

    local _payload = {
      type = 'project',
      project = entry.project,
      count = #entry.issues,
      expanded = true,
    }
    table.insert(nodes, n.node(_payload))
    table.insert(flat_issues, _payload)
    for _, issue in ipairs(entry.issues) do
      local _issue = {
        type = 'issue',
        project_id = entry.project.id,
        issue = issue,
      }
      table.insert(nodes, n.node(_issue))
      table.insert(flat_issues, _issue)
    end
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
    on_change = function(node)
      if node.type == 'issue' then
        local issue = node.issue
        signal.selected = issue.id

        -- open issue in browser
        vim.keymap.set("n", props.options.keymap.open_issue, function()
          local url = string.format("%s/view.php?id=%d", props.host.url, issue.id)
          vim.system({ 'xdg-open', url }, { detach = true })
        end)

        -- assign user
        vim.keymap.set("n", props.options.keymap.assign_issue, function()
          props.on_assign_user(issue.id, issue.project.id, function()
            renderer:close()
          end)
        end)

        -- change status
        vim.keymap.set("n", props.options.keymap.change_status, function()
          props.on_change_status(issue.id, function()
            renderer:close()
          end)
        end)
      end
    end,
    on_focus = function(state)
      -- refresh issues view
      vim.keymap.set("n", props.options.keymap.refresh, function()
        props.on_refresh(function()
          renderer:close()
        end)
      end)

      -- quit with 'q'
      vim.keymap.set("n", props.options.keymap.quit, function()
        renderer:close()
      end)

        -- prev page
        vim.keymap.set("n", props.options.keymap.prev_page, function()
          if props.has_prev_page then
            props.on_prev_page(function()
              renderer:close()
            end)
          end
        end)

        -- next page
        vim.keymap.set("n", props.options.keymap.next_page, function()
          props.on_next_page(function()
            if props.has_next_page then
              renderer:close()
            end
          end)
        end)
    end,
    on_mount = function(component)
      if props.has_next_page then
        component:set_border_text("bottom", "Page: " .. props.page, "right")
      end
    end,
    on_select = function(node, component)
      -- print(node.issue.id)
    end,
    prepare_node = function(node, line, component)
      local type = node.type

      if type == 'project' then
        local project = node.project
        line:append(n.text(string.format("  %s (%d)", project.name, node.count), "Directory"))
      elseif type == 'issue' then
        local issue = node.issue
        local column_width = props.options.ui.column_width

        line:append(n.text("   └── ", "Comment"))

        local status_bg = "MantisStatusBg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_bg, { bg = issue.status.color })
        local status_fg = "MantisStatusFg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_fg, { fg = issue.status.color })

        local s_colour = n.text(string.format(column_width.s_color, "●"), status_fg)
        line:append(s_colour)

        local id = n.text(string.format(column_width.id, issue.id), status_fg)
        line:append(id)

        local severity = n.text(string.format(column_width.severity, "[" .. util.truncate(issue.severity.label, 8) .. "]"), status_fg)
        line:append(severity)

        local status = n.text(
        string.format(column_width.status, issue.status.label .. ' (' .. util.truncate(issue.handler.name, 8) .. ')'), status_fg)
        line:append(status)

        local category = n.text(string.format(column_width.category, util.truncate(issue.category.name, 12)), "Identifier")
        line:append(category)

        local summary = n.text(string.format(column_width.summary, util.truncate(issue.summary, 70)))
        line:append(summary)

        local updated = n.text(string.format(column_width.updated, util.time_ago(util.parse_iso8601(issue.updated_at))), "Comment")
        line:append(updated)
      end

      return line
    end,
  })
  renderer:render(n.rows(tree))
end

function M.render(props)
  _render_tree(props)
end

return M
