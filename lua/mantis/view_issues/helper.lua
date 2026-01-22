local M = {}

local state = require("mantis.state")
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")
local options = config.options.view_issues

function M.get_help()
  local keymap = options.keymap
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
        { key = "filter",          label = "Filter" },
        { key = "add_note",        label = "Add note" },
        { key = "create_issue",    label = "Create issue" },
        { key = "delete_issue",    label = "Delete issue" },
        { key = "assign_issue",    label = "Assign issue" },
        { key = "change_summary",   label = "Change summary" },
        { key = "change_status",   label = "Change status" },
        { key = "change_severity", label = "Change severity" },
        { key = "change_priority", label = "Change priority" },
        { key = "change_category", label = "Change category" },
      },
    },
    {
      title = "Essential",
      items = {
        { key = "toggle_group", label = "Toggle group" },
        { key = "refresh",      label = "Refresh" },
        { key = "quit",         label = "Quit" },
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

function M.prepare_node(node, line, component)
  local type = node.type

  if type == 'project' then
    local project = node.project
    line:append(n.text("──", "Comment"))
    line:append(n.text(string.format("  %s (%d)", project.name, node.count), "Directory"))
  elseif type == 'issue' then
    local issue = node.issue
    local columns = options.ui.columns

    if node.ungrouped then
      line:append(n.text("  ", "Comment"))
    elseif node.index == node.count then
      line:append(n.text("  └── ", "Comment"))
    else
      line:append(n.text("  ├── ", "Comment"))
    end

    local status_bg = "MantisStatusBg_" .. issue.status.label
    vim.api.nvim_set_hl(0, status_bg, { bg = issue.status.color })
    local status_fg = "MantisStatusFg_" .. issue.status.label
    vim.api.nvim_set_hl(0, status_fg, { fg = issue.status.color })

    if columns.priority then
      local priority_emojis = config.options.priority_emojis
      local label = issue.priority.label
      local key = label:lower()
      local emoji = priority_emojis[key] or priority_emojis['default']
      if issue.status.label == 'resolved' or issue.status.label == 'closed' then
        emoji = config.options.priority_emojis.complete
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
      local updated_text = M.time_ago(issue.updated_at)
      local updated = n.text(
        string.format("%" .. columns.updated .. "s", util.truncate(updated_text, columns.updated)), "Comment")
      line:append(updated)
    end
  end

  return line
end

function M.build_nodes(issues, grouped)
  local nodes = {}

  -- default to grouped if not specified
  if grouped == nil then
    grouped = true
  end

  if not grouped then
    -- flat list sorted by updated_at
    local sorted_issues = {}
    for _, issue in ipairs(issues) do
      table.insert(sorted_issues, issue)
    end
    table.sort(sorted_issues, function(a, b)
      return a.updated_at > b.updated_at
    end)

    for i, issue in ipairs(sorted_issues) do
      local _issue = {
        index = i,
        count = #sorted_issues,
        type = 'issue',
        issue = issue,
        ungrouped = true,
      }
      table.insert(nodes, n.node(_issue))
    end

    return nodes
  end

  -- grouped by project
  local projects = {}
  local sorted_projects = {}

  for _, issue in ipairs(issues) do
    local pid = issue.project.id
    if not projects[pid] then
      projects[pid] = { project = issue.project, issues = {} }
    end
    table.insert(projects[pid].issues, issue)
  end

  -- sort projects by name
  for _, project_entry in pairs(projects) do
    table.insert(sorted_projects, project_entry)
  end
  table.sort(sorted_projects, function(a, b)
    return a.project.name < b.project.name
  end)

  -- flatten issues
  for _, entry in ipairs(sorted_projects) do
    -- sort issues by updated_at
    table.sort(entry.issues, function(a, b)
      return a.updated_at > b.updated_at
    end)

    local node = {
      type = 'project',
      project = entry.project,
      count = #entry.issues,
    }
    table.insert(nodes, n.node(node))

    local project_id = entry.project.id
    local collapsed = false
    for _, id in ipairs(state.collapsed_projects) do
      if id == project_id then
        collapsed = true
        break
      end
    end

    if not collapsed then
      for i, issue in ipairs(entry.issues) do
        local _issue = {
          index = i,
          count = #entry.issues,
          type = 'issue',
          issue = issue,
        }
        table.insert(nodes, n.node(_issue))
      end
    end
  end

  return nodes
end

-- time_ago is now provided by util module
M.time_ago = util.time_ago

return M
