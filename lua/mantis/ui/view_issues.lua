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
    for i, issue in ipairs(entry.issues) do
      local _issue = {
        index = i,
        count = #entry.issues,
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

  local function _get_help()
    local keymap = props.options.keymap
    local COLUMN_GAP = 2

    -- help menu, grouped kinda like neogit
    local groups = {
      {
        title = "Navigation",
        items = {
          { key = "next_page",  label = "Next page" },
          { key = "prev_page",  label = "Prev page" },
          { key = "open_issue", label = "Open issue" },
        },
      },
      {
        title = "Issues",
        items = {
          { key = "create_issue",    label = "Create issue" },
          { key = "assign_issue",    label = "Assign issue" },
          { key = "change_status",   label = "Change status" },
          { key = "change_severity", label = "Change severity" },
          { key = "change_priority", label = "Change priority" },
        },
      },
      {
        title = "Essential",
        items = {
          { key = "refresh", label = "Refresh" },
          { key = "quit",    label = "Quit" },
        },
      },
    }

    -- resolve key mappings
    for _, group in ipairs(groups) do
      local resolved = {}
      for _, item in ipairs(group.items) do
        local key = keymap[item.key]
        if key then
          table.insert(resolved, {
            key = key,
            label = item.label,
          })
        end
      end
      group.items = resolved
    end

    -- per-column width calculation (no gap included)
    for _, group in ipairs(groups) do
      local key_w   = #group.title
      local label_w = 0

      for _, item in ipairs(group.items) do
        key_w   = math.max(key_w, #item.key)
        label_w = math.max(label_w, #item.label)
      end

      group.key_width   = key_w
      group.label_width = label_w
      group.col_width   = key_w + 1 + label_w
    end

    -- max rows
    local max_rows = 0
    for _, group in ipairs(groups) do
      max_rows = math.max(max_rows, #group.items)
    end

    local lines = {}

    local function join_columns(cols)
      return table.concat(cols, string.rep(" ", COLUMN_GAP))
    end

    -- header
    do
      local header = {}
      for _, group in ipairs(groups) do
        table.insert(
          header,
          string.format("%-" .. group.col_width .. "s", group.title)
        )
      end
      table.insert(lines, n.line(n.text(join_columns(header), "Special")))
    end

    -- separator
    do
      local sep = {}
      for _, group in ipairs(groups) do
        table.insert(sep, string.rep("-", group.col_width))
      end
      table.insert(lines, n.line(join_columns(sep)))
    end

    -- rows
    for row = 1, max_rows do
      local cols = {}

      for _, group in ipairs(groups) do
        local item = group.items[row]
        if item then
          table.insert(
            cols,
            string.format(
              "%-" .. group.key_width .. "s %-"
              .. group.label_width .. "s",
              item.key,
              item.label
            )
          )
        else
          table.insert(cols, string.rep(" ", group.col_width))
        end
      end

      table.insert(lines, n.line(join_columns(cols)))
    end

    return lines
  end


  local function update_issue(updated)
    for i, issue in ipairs(props.issues) do
      if issue.id == updated.id then
        props.issues[i] = updated
      end
    end
  end

  local tree = n.tree({
    flex = 1,
    autofocus = true,
    border_label = "MantisBT Issues",
    data = build_nodes(props.issues),
    on_change = function(node)
      local keymap = props.options.keymap
      if node.type == 'issue' then
        local issue = node.issue
        signal.selected = issue.id

        -- open issue in browser
        vim.keymap.set("n", keymap.open_issue, function()
          local url = string.format("%s/view.php?id=%d", props.host.url, issue.id)
          vim.system({ 'xdg-open', url }, { detach = true })
        end, { desc = "Open issue in browser" })

        -- assign user
        vim.keymap.set("n", keymap.assign_issue, function()
          props.on_assign_user(issue.id, issue.project.id, function(issue)
            update_issue(issue)
            renderer:close()
            M.render(props)
          end, { desc = "Assign user" })
        end)

        -- change severity
        vim.keymap.set("n", keymap.change_severity, function()
          props.on_change_severity(issue.id, function(new_issue)
            update_issue(new_issue)
            renderer:close()
            M.render(props)
          end)
        end, { desc = "Change severity" })

        -- change priority
        vim.keymap.set("n", keymap.change_priority, function()
          props.on_change_priority(issue.id, function(new_issue)
            update_issue(new_issue)
            renderer:close()
            M.render(props)
          end)
        end, { desc = "Change priority" })

        -- change status
        vim.keymap.set("n", keymap.change_status, function()
          props.on_change_status(issue.id, function(new_issue)
            update_issue(new_issue)
            renderer:close()
            M.render(props)
          end)
        end, { desc = "Change status" })
      end
    end,
    on_focus = function(state)
      local keymap = props.options.keymap
      -- show help
      vim.keymap.set("n", keymap.help, function()
        local show = signal.show_help:get_value()
        signal.show_help = not show
      end)

      -- refresh issues view
      vim.keymap.set("n", keymap.refresh, function()
        props.on_refresh(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Refresh issues" })

      -- quit with 'q'
      vim.keymap.set("n", keymap.quit, function()
        renderer:close()
      end)

      -- create new issue
      vim.keymap.set("n", keymap.create_issue, function()
        props.on_create_issue()
        renderer:close()
      end, { desc = "Create new issue" })

      -- prev page
      vim.keymap.set("n", keymap.prev_page, function()
        props.on_prev_page(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Prev page" })

      -- next page
      vim.keymap.set("n", keymap.next_page, function()
        props.on_next_page(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Next page" })
    end,
    on_mount = function(component)
      component:set_border_text("bottom", "[" .. props.options.keymap.help .. "] help", "left")
    end,
    on_select = function(node, component)
      local type = node.type
      if type == 'project' then
        node.expanded = not node.expanded
      end
    end,
    prepare_node = function(node, line, component)
      local type = node.type

      if type == 'project' then
        local project = node.project
        line:append(n.text("──", "Comment"))
        line:append(n.text(string.format(" %s (%d)", project.name, node.count), "Function"))
      elseif type == 'issue' then
        local issue = node.issue
        local column_width = props.options.ui.column_width

        if node.index == node.count then
          line:append(n.text("  └── ", "Comment"))
        else
          line:append(n.text("  ├── ", "Comment"))
        end

        local status_bg = "MantisStatusBg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_bg, { bg = issue.status.color })
        local status_fg = "MantisStatusFg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_fg, { fg = issue.status.color })

        if column_width.s_color then
          local s_colour = n.text(string.format("%" .. column_width.s_color .. "s ", props.options.ui.status_symbol),
            status_fg)
          line:append(s_colour)
        end

        if column_width.id then
          local id = n.text(
            string.format("%0" .. column_width.id .. "d ", util.truncate(tostring(issue.id), column_width.id)), status_fg)
          line:append(id)
        end

        if column_width.status then
          local handler = issue.handler and issue.handler.name or 'n/a'
          local status_text = issue.status.label .. ' (' .. handler .. ')'
          local status = n.text(
            string.format("%-" .. column_width.status .. "s ", util.truncate(status_text, column_width.status)),
            status_fg)
          line:append(status)
        end

        if column_width.priority then
          local priority_emoji = {
            immediate = "🔥",
            urgent    = "⚠️",
            high      = "🟠",
            normal    = "🟢",
            low       = "🔵",
            default   = "⚪"
          }
          local label = issue.priority.label
          local key = label:lower()
          local emoji = priority_emoji[key] or priority_emoji['default']

          line:append(n.text(string.format("%-" .. column_width.priority .. "s ", emoji)))
        end

        if column_width.category then
          local category = n.text(
            string.format("%-" .. column_width.category .. "s ",
              util.truncate(issue.category.name, column_width.category)), "Type")
          line:append(category)
        end


        if column_width.severity then
          local severity_text = "[" .. issue.severity.label .. "]"
          local severity = n.text(
            string.format("%-" .. column_width.severity .. "s ", util.truncate(severity_text, column_width.severity)),
            "Identifier")
          line:append(severity)
        end

        if column_width.summary then
          local summary = n.text(string.format("%-" .. column_width.summary .. "s ",
            util.truncate(issue.summary, column_width.summary)))
          line:append(summary)
        end

        if column_width.updated then
          local updated_text = util.time_ago(util.parse_iso8601(issue.updated_at))
          local updated = n.text(
            string.format("%" .. column_width.updated .. "s", util.truncate(updated_text, column_width.updated)),
            "Comment")
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
      lines = _get_help(),
      align = "center"
    })
  ))
end

function M.render(props)
  _render_tree(props)
end

return M
