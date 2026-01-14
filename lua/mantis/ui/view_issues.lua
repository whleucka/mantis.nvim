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

  -- flatten issues
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
    show_help = false,
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
        end, { desc = "Open issue in browser" })

        -- assign user
        vim.keymap.set("n", props.options.keymap.assign_issue, function()
          props.on_assign_user(issue.id, issue.project.id, function()
            renderer:close()
          end, { desc = "Assign user" })
        end)

        -- change status
        vim.keymap.set("n", props.options.keymap.change_status, function()
          props.on_change_status(issue.id, function()
            renderer:close()
          end)
        end, { desc = "Change status" })
      end
    end,
    on_focus = function(state)
      -- show help
      vim.keymap.set("n", "h", function()
        local show = signal.show_help:get_value()
        signal.show_help = not show
      end)

      -- refresh issues view
      vim.keymap.set("n", props.options.keymap.refresh, function()
        props.on_refresh(function()
          renderer:close()
        end)
      end, { desc = "Refresh issues" })

      -- quit with 'q'
      vim.keymap.set("n", props.options.keymap.quit, function()
        renderer:close()
      end)

      -- create new issue
      vim.keymap.set("n", props.options.keymap.create_issue, function()
        props.on_create_issue()
        renderer:close()
      end, { desc = "Create new issue" })

      -- prev page
      vim.keymap.set("n", props.options.keymap.prev_page, function()
        if props.has_prev_page then
          props.on_prev_page(function()
            renderer:close()
          end)
        end
      end, { desc = "Prev page" })

      -- next page
      vim.keymap.set("n", props.options.keymap.next_page, function()
        props.on_next_page(function()
          if props.has_next_page then
            renderer:close()
          end
        end)
      end, { desc = "Next page" })

    end,
    on_mount = function(component)
      component:set_border_text("bottom", "[h]elp", "left")
    end,
    on_select = function(node, component)
      local type = node.type
      if type == 'project' then
        node.expanded = not node.expanded
        util.debug(node.expanded)
      end
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

        if column_width.s_color then
          local s_colour = n.text(string.format("%" .. column_width.s_color .. "s ", "●"), status_fg)
          line:append(s_colour)
        end

        if column_width.id then
          local id = n.text(
          string.format("%0" .. column_width.id .. "d ", util.truncate(tostring(issue.id), column_width.id)), status_fg)
          line:append(id)
        end

        if column_width.severity then
          local severity_text = "[" .. issue.severity.label .. "]"
          local severity = n.text(
          string.format("%-" .. column_width.severity .. "s ", util.truncate(severity_text, column_width.severity)),
            status_fg)
          line:append(severity)
        end

        if column_width.status then
          local handler = issue.handler and issue.handler.name or 'n/a'
          local status_text = issue.status.label .. ' (' .. handler .. ')'
          local status = n.text(
            string.format("%-" .. column_width.status .. "s ", util.truncate(status_text, column_width.status)),
            status_fg)
          line:append(status)
        end

        if column_width.category then
          local category = n.text(
          string.format("%-" .. column_width.category .. "s ", util.truncate(issue.category.name, column_width.category)),
            "Identifier")
          line:append(category)
        end

        if column_width.summary then
          local summary = n.text(string.format("%-" .. column_width.summary .. "s ",
            util.truncate(issue.summary, column_width.summary)))
          line:append(summary)
        end

        if column_width.updated then
          local updated_text = util.time_ago(util.parse_iso8601(issue.updated_at))
          local updated = n.text(
          string.format("%" .. column_width.updated .. "s", util.truncate(updated_text, column_width.updated)), "Comment")
          line:append(updated)
        end
      end

      return line

    end,
  })
  renderer:render(n.rows(
    tree,
    n.paragraph({
      hidden = signal.show_help:negate(),
      lines = "quit: q",
      align = "center"
    })
  ))
end

function M.render(props)
  _render_tree(props)
end

return M
