local M = {}

local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")
local options = config.options.view_issues

function M.prepare_node(node, line, component)
      local type = node.type

      if type == 'project' then
        local project = node.project
        line:append(n.text("──", "Comment"))
        line:append(n.text(string.format("  %s (%d)", project.name, node.count), "Directory"))
      elseif type == 'issue' then
        local issue = node.issue
        local columns = options.ui.columns

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
          local updated_text = util.time_ago(issue.updated_at)
          local updated = n.text(
            string.format("%" .. columns.updated .. "s", util.truncate(updated_text, columns.updated)), "Comment")
          line:append(updated)
        end
      end

      return line
  end

function M.build_nodes(issues)
  local nodes = {}
  local projects = {}
  local sorted_projects = {}

  -- projects are grouped
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

  return nodes
end
return M
