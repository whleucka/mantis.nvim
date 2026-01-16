local M = {}
local n = require("nui-components")
local util = require("mantis.util")

local function _build_nodes(issues)
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
    }
    table.insert(nodes, n.node(_payload))
    for i, issue in ipairs(entry.issues) do
      if issue.expanded == nil then issue.expanded = true end
      local _issue = {
        index = i,
        count = #entry.issues,
        type = 'issue',
        issue = issue,
      }
      table.insert(nodes, n.node(_issue))
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

  local function _toggle_expand(project_id)
    for i, issue in ipairs(props.issues) do
      if issue.project.id == project_id then
        local expanded = props.issues[i].expanded
        props.issues[i].expanded = not expanded
      end
    end
  end


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
          { key = "add_note",        label = "Add note" },
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


  local function _update_issue(updated)
    for i, issue in ipairs(props.issues) do
      if issue.id == updated.id then
        props.issues[i] = updated
      end
    end
  end

  local tree = n.tree({
    flex = 1,
    autofocus = true,
    border_label = " MantisBT Issues [" .. props.current_host .. "] ",
    data = _build_nodes(props.issues),
    on_change = function(node)
      if node.type == 'issue' then
        local issue = node.issue
        signal.selected = issue
      elseif node.type == 'project' then
        local project = node.project
        signal.selected = project
      end
    end,
    on_focus = function(state)
      local keymap = props.options.keymap
      -- show help
      vim.keymap.set("n", keymap.help, function()
        local show = signal.show_help:get_value()
        signal.show_help = not show
      end, { buffer = true })

      -- refresh issues view
      vim.keymap.set("n", keymap.refresh, function()
        props.on_refresh(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Refresh issues", buffer = true })

      -- quit with 'q'
      vim.keymap.set("n", keymap.quit, function()
        renderer:close()
      end, { buffer = true })

      -- add note
      vim.keymap.set("n", keymap.add_note, function()
        local issue = signal.selected:get_value()
        props.on_add_note(issue.id)
        renderer:close()
      end, { desc = "Add note", buffer = true })

      -- create new issue
      vim.keymap.set("n", keymap.create_issue, function()
        props.on_create_issue()
        renderer:close()
      end, { desc = "Create new issue", buffer = true })

      -- prev page
      vim.keymap.set("n", keymap.prev_page, function()
        props.on_prev_page(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Prev page", buffer = true })

      -- next page
      vim.keymap.set("n", keymap.next_page, function()
        props.on_next_page(function(issues)
          props.issues = issues
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Next page", buffer = true })

      -- open issue in browser
      vim.keymap.set("n", keymap.open_issue, function()
        local issue = signal.selected:get_value()
        local url = string.format("%s/view.php?id=%d", props.host.url, issue.id)
        vim.system({ 'xdg-open', url }, { detach = true })
      end, { desc = "Open issue in browser", buffer = true })

      -- assign user
      vim.keymap.set("n", keymap.assign_issue, function()
        local issue = signal.selected:get_value()
        props.on_assign_user(issue.id, issue.project.id, function(issue)
          _update_issue(issue)
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Assign user", buffer = true })

      -- change severity
      vim.keymap.set("n", keymap.change_severity, function()
        local issue = signal.selected:get_value()
        props.on_change_severity(issue.id, function(new_issue)
          _update_issue(new_issue)
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Change severity", buffer = true })

      -- change priority
      vim.keymap.set("n", keymap.change_priority, function()
        local issue = signal.selected:get_value()
        props.on_change_priority(issue.id, function(new_issue)
          _update_issue(new_issue)
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Change priority", buffer = true })

      -- change status
      vim.keymap.set("n", keymap.change_status, function()
        local issue = signal.selected:get_value()
        props.on_change_status(issue.id, function(new_issue)
          _update_issue(new_issue)
          renderer:close()
          M.render(props)
        end)
      end, { desc = "Change status", buffer = true })
    end,
    on_mount = function(component)
      component:set_border_text("bottom", " " .. props.options.keymap.help .. " help ", "left")
    end,
    on_select = function(node, component)
      -- TODO this works, but it causes errors because scrollable height has changed
      -- if node.type == 'project' then
      --   _toggle_expand(node.project.id)
      --   renderer:close()
      --   M.render(props)
      -- end
    end,
    prepare_node = function(node, line, component)
      local type = node.type

      if type == 'project' then
        local project = node.project
        line:append(n.text("──", "Comment"))
        line:append(n.text(string.format(" %s (%d)", project.name, node.count), "Directory"))
      elseif type == 'issue' then
        local issue = node.issue
        if not issue.expanded then return end
        local columns = props.options.ui.columns

        if node.index == node.count then
          line:append(n.text("  └── ", "Comment"))
        else
          line:append(n.text("  ├── ", "Comment"))
        end

        local status_bg = "MantisStatusBg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_bg, { bg = issue.status.color })
        local status_fg = "MantisStatusFg_" .. issue.status.label
        vim.api.nvim_set_hl(0, status_fg, { fg = issue.status.color })

        if columns.priority then
          local priority_emoji = {
            immediate = "🔥",
            urgent    = "⚠️",
            high      = "🔴",
            normal    = "🟢",
            low       = "🔵",
            default   = "⚪"
          }
          local label = issue.priority.label
          local key = label:lower()
          local emoji = priority_emoji[key] or priority_emoji['default']
          if issue.status.label == 'resolved' or issue.status.label == 'closed' then
            emoji = "✅"
          end

          line:append(n.text(string.format("%-" .. columns.priority .. "s ", emoji)))
        end

        if columns.id then
          local id = n.text(string.format("%0" .. columns.id .. "d ", util.truncate(tostring(issue.id), columns.id)),
            status_fg)
          line:append(id)
        end

        if columns.status then
          local handler = issue.handler and issue.handler.name or 'n/a'
          local status_text = issue.status.label .. ' (' .. handler .. ')'
          local status = n.text(
            string.format("%-" .. columns.status .. "s ", util.truncate(status_text, columns.status)), status_fg)
          line:append(status)
        end


        if columns.category then
          local category = n.text(
            string.format("%-" .. columns.category .. "s ", util.truncate(issue.category.name, columns.category)), "Type")
          line:append(category)
        end


        if columns.severity then
          local severity_text = "[" .. issue.severity.label .. "]"
          local severity = n.text(
            string.format("%-" .. columns.severity .. "s ", util.truncate(severity_text, columns.severity)), "Identifier")
          line:append(severity)
        end

        if columns.summary then
          local summary = n.text(string.format("%-" .. columns.summary .. "s ",
            util.truncate(issue.summary, columns.summary)))
          line:append(summary)
        end

        if columns.updated then
          local updated_text = util.time_ago(util.parse_iso8601(issue.updated_at))
          local updated = n.text(
            string.format("%" .. columns.updated .. "s", util.truncate(updated_text, columns.updated)), "Comment")
          line:append(updated)
        end
      end

      return line
    end,
  })

  local help = n.paragraph({
    hidden = signal.show_help:negate(),
    lines = _get_help(),
    align = "center"
  })
  renderer:render(n.rows(
    tree,
    help
  ))
end

function M.render(props)
  _render_tree(props)
end

return M
