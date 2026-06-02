local M = {}

local state = require("mantis.state")
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")
local options = config.options.view_issues

-- Calculate the effective window width from config (handles percentages)
local function get_effective_width()
  local width = options.ui.width
  if type(width) == "string" and width:match("%%$") then
    local pct = tonumber(width:match("^(%d+)")) or 90
    return math.floor(vim.o.columns * pct / 100)
  end
  return width or 150
end

-- Cache for created highlight groups (avoids redundant nvim_set_hl calls)
local hl_cache = {}

-- Calculate summary column width based on available space
function M.get_summary_width()
  local columns = options.ui.columns
  local width = get_effective_width()

  -- Fixed overhead: checkbox (4) + tree prefix (4) + border (4) + padding
  local overhead = 13

  -- Sum of fixed column widths (each has 1 space after)
  local fixed_width = 0
  for col, w in pairs(columns) do
    if col ~= "summary" and w then
      fixed_width = fixed_width + w + 1  -- +1 for space after each column
    end
  end

  -- Remaining space for summary
  local summary_width = width - overhead - fixed_width
  -- Clamp between 20 and 99 (Lua format specifier width limit)
  return math.max(20, math.min(99, summary_width))
end

function M.prepare_node(node, line, component)
  local type = node.type

  if type == 'empty' then
    local message = "🎉 There are currently no issues"
    local width = get_effective_width()
    local padding = math.floor((width - #message) / 2)
    line:append(n.text(string.rep(" ", padding) .. message, "Comment"))
  elseif type == 'project' then
    local project = node.project
    line:append(n.text("──", "Comment"))
    line:append(n.text(string.format("  %s (%d)", project.name, node.count), "Directory"))
  elseif type == 'issue' then
    local issue = node.issue
    local columns = options.ui.columns

    -- Selection checkbox
    local is_selected = state.is_selected(issue.id)
    local checkbox = is_selected and "[x] " or "[ ] "
    local checkbox_hl = is_selected and "DiagnosticOk" or "Comment"
    line:append(n.text(checkbox, checkbox_hl))

    if node.ungrouped then
      line:append(n.text("", "Comment"))
    elseif node.index == node.count then
      line:append(n.text("└── ", "Comment"))
    else
      line:append(n.text("├── ", "Comment"))
    end

    local status_color = issue.status.color
    -- Validate color: must be a hex color (#RRGGBB or #RGB) or a valid named color
    -- CSS values like 'currentcolor' are not valid in Neovim
    if not status_color or not status_color:match("^#%x+$") then
      status_color = "#808080" -- fallback to gray
    end
    local status_bg = "MantisStatusBg_" .. issue.status.label
    local status_fg = "MantisStatusFg_" .. issue.status.label
    if not hl_cache[status_fg] then
      vim.api.nvim_set_hl(0, status_bg, { bg = status_color })
      vim.api.nvim_set_hl(0, status_fg, { fg = status_color })
      hl_cache[status_bg] = true
      hl_cache[status_fg] = true
    end

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
      -- Zero-pad the numeric id to the column width. Never run it through
      -- truncate(): that returns "…" past the width and would crash %d.
      local id = n.text(string.format("%0" .. columns.id .. "d ", issue.id), status_fg)
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

    -- Summary column uses dynamic width (capped at 99 for Lua format limit)
    local summary_width = math.min(columns.summary or M.get_summary_width(), 99)
    local summary = n.text(string.format("%-" .. summary_width .. "s ",
      util.truncate(issue.summary, summary_width)))
    line:append(summary)

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

  -- empty state
  if not issues or #issues == 0 then
    table.insert(nodes, n.node({ type = 'empty' }))
    return nodes
  end

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
