local M = {}
local n = require("nui-components")
local util = require("mantis.util")
local config = require("mantis.config")

local function _build_nodes(issues, collapsed_projects)
  local projects = {}

  for _, issue in ipairs(issues) do
    local pid = issue.project.id
    if not projects[pid] then
      projects[pid] = { project = issue.project, issues = {} }
    end
    table.insert(projects[pid].issues, issue)
  end

  local nodes = {}

  local sorted_projects = {}
  for _, project_entry in pairs(projects) do
    table.insert(sorted_projects, project_entry)
  end
  table.sort(sorted_projects, function(a, b)
    return a.project.name < b.project.name
  end)

  -- flatten issues
  for _, entry in ipairs(sorted_projects) do
    local pid = entry.project.id
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
    if not collapsed_projects[pid] then
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

local function _format_issue_details(issue)
  local lines = {}

  local function _split_and_insert_lines(lines_table, text, indent)
    indent = indent or ""
    if text == nil or text == "" then
      return
    end
    local text_lines = vim.split(text, "\n")
    for _, line in ipairs(text_lines) do
      table.insert(lines_table, indent .. line)
    end
  end

  table.insert(lines, string.format("Issue #%s: %s", issue.id, issue.summary))
  table.insert(lines, "")
  table.insert(lines, string.format("**Project**: %s", issue.project.name))
  table.insert(lines, string.format("**Category**: %s", issue.category.name))
  table.insert(lines, string.format("**Reporter**: %s (%s)", issue.reporter.real_name, issue.reporter.name))
  table.insert(lines, "")
  table.insert(lines, string.format("**Status**: %s", issue.status.label))
  table.insert(lines, string.format("**Resolution**: %s", issue.resolution.label))
  table.insert(lines, string.format("**Priority**: %s", issue.priority.label))
  table.insert(lines, string.format("**Severity**: %s", issue.severity.label))
  table.insert(lines, "")
  table.insert(lines, string.format("**Created**: %s", util.time_ago(util.parse_iso8601(issue.created_at))))
  table.insert(lines, string.format("**Updated**: %s", util.time_ago(util.parse_iso8601(issue.updated_at))))
  table.insert(lines, "")
  table.insert(lines, "Description")
  table.insert(lines, "")
  _split_and_insert_lines(lines, issue.description)
  table.insert(lines, "")

  if issue.notes and #issue.notes > 0 then
    table.insert(lines, "Notes")
    table.insert(lines, "")
    for _, note in ipairs(issue.notes) do
      local user = note.reporter.real_name or note.reporter.name
      local t = util.time_ago(util.parse_iso8601(note.created_at))
      table.insert(lines, string.format("[%s] **%s**:", t, user))
      _split_and_insert_lines(lines, note.text, "")
      table.insert(lines, "")
    end
    table.insert(lines, "")
    table.insert(lines, "")
  end

  if issue.custom_fields and #issue.custom_fields > 0 then
    table.insert(lines, "Custom Fields")
    table.insert(lines, "")
    for _, field in ipairs(issue.custom_fields) do
      table.insert(lines, string.format("- **%s**: %s", field.field.name, field.value))
    end
    table.insert(lines, "")
  end

  if issue.history and #issue.history > 0 then
    table.insert(lines, "History")
    table.insert(lines, "")
    for _, item in ipairs(issue.history) do
      local user = item.user.real_name or item.user.name
      local t = util.time_ago(util.parse_iso8601(item.created_at))
      _split_and_insert_lines(lines, string.format("- [%s] **%s**: %s", t, user, item.message))
    end
    table.insert(lines, "")
  end

  return lines
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
    props.collapsed_projects[project_id] = not props.collapsed_projects[project_id]
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

  local function _change_issue_property(issue_id, property, options)
    vim.ui.select(options, { prompt = "Select a " .. property }, function(value)
      if not value then return end
      local payload = {}
      payload[property] = { name = value }
      local res = props.mantis_api_client_factory():update_issue(issue_id, payload)

      if value and res then
        local issue = (res and res.issues[1]) or {}
        _update_issue(issue)
        renderer:close()
        M.render(props)
      end
    end)
  end

  local ns = vim.api.nvim_create_namespace("mantis_issue_preview")

  local function create_floating_window(title)
    local buf                 = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype      = "markdown"

    local width               = math.floor(vim.o.columns * 0.6)
    local height              = math.floor(vim.o.lines * 0.6)
    local row                 = math.floor((vim.o.lines - height) / 2)
    local col                 = math.floor((vim.o.columns - width) / 2)

    local win                 = vim.api.nvim_open_win(buf, true, {
      style = "minimal",
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      border = "single",
      zindex = 150,
      title = title,
    })

    vim.wo[win].wrap          = true
    vim.wo[win].conceallevel  = 2
    vim.wo[win].concealcursor = "n"

    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true })

    return buf, win
  end

  local function highlight_issue_buffer(buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for i, line in ipairs(lines) do
      local row = i - 1

      -- Title (first line)
      if row == 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          end_col = #line,
          hl_group = "Title",
        })
      end

      -- Section headers
      if line == "Description"
          or line == "Notes"
          or line == "Custom Fields"
          or line == "History"
      then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          end_col = #line,
          hl_group = "Title",
        })
      end

      -- **bold**
      local start = 1
      while true do
        local s, e = line:find("%*%*([^*]+)%*%*", start)
        if not s then break end

        -- Bold text
        vim.api.nvim_buf_set_extmark(buf, ns, row, s, {
          end_col = e - 2,
          hl_group = "Statement",
        })

        -- Conceal **
        vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, {
          end_col = s + 1,
          conceal = "",
        })

        vim.api.nvim_buf_set_extmark(buf, ns, row, e - 2, {
          end_col = e,
          conceal = "",
        })

        start = e + 1
      end
    end
  end

  local tree = n.tree({
    flex = 1,
    autofocus = true,
    border_label = " MantisBT Issues [" .. props.current_host .. "] ",
    data = _build_nodes(props.issues, props.collapsed_projects),
    on_change = function(node)
      if node.type == 'issue' then
        local issue = node.issue
        signal.selected = issue
      end
    end,
    on_focus = function()
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
        props.on_add_note(issue.id, function()
          renderer:close()
        end)
      end, { desc = "Add note", buffer = true })

      -- create new issue
      vim.keymap.set("n", keymap.create_issue, function()
        props.on_create_issue(function()
          renderer:close()
        end)
      end, { desc = "Create new issue", buffer = true })

      -- prev page
      vim.keymap.set("n", keymap.prev_page, function()
        props.on_prev_page(function(issues)
          if issues then
            props.page = props.page - 1
            props.issues = issues
            renderer:close()
            M.render(props)
          end
        end)
      end, { desc = "Prev page", buffer = true })

      -- next page
      vim.keymap.set("n", keymap.next_page, function()
        props.on_next_page(function(issues)
          if issues then
            props.page = props.page + 1
            props.issues = issues
            renderer:close()
            M.render(props)
          end
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
        _change_issue_property(issue.id, "severity", config.options.issue_severity_options)
      end, { desc = "Change severity", buffer = true })

      -- change priority
      vim.keymap.set("n", keymap.change_priority, function()
        local issue = signal.selected:get_value()
        _change_issue_property(issue.id, "priority", config.options.issue_priority_options)
      end, { desc = "Change priority", buffer = true })

      -- change status
      vim.keymap.set("n", keymap.change_status, function()
        local issue = signal.selected:get_value()
        _change_issue_property(issue.id, "status", config.options.issue_status_options)
      end, { desc = "Change status", buffer = true })
    end,
    on_mount = function(component)
      component:set_border_text("bottom", " " .. props.options.keymap.help .. " help  [page: " .. props.page .. "] ",
        "right")
    end,
    on_select = function(node, component)
      if node.type == "project" then
        _toggle_expand(node.project.id)
        renderer:close()
        M.render(props)
        return
      end

      if node.type ~= "issue" then
        return
      end

      local issue = node.issue
      local buf, win = create_floating_window("Issue #" .. issue.id)

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Fetching issue details..."
      })

      vim.bo[buf].modifiable = true

      local res = props.mantis_api_client_factory():get_issue(issue.id)
      if res and res.issues and #res.issues > 0 then
        local issue_details = res.issues[1]
        local lines = _format_issue_details(issue_details)

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        highlight_issue_buffer(buf)
      else
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "Failed to get issue details."
        })
      end

      vim.bo[buf].modifiable = false
    end,
    prepare_node = function(node, line, component)
      local type = node.type

      if type == 'project' then
        local project = node.project
        line:append(n.text("──", "Comment"))
        line:append(n.text(string.format(" %s (%d)", project.name, node.count), "Directory"))
      elseif type == 'issue' then
        local issue = node.issue
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
          local priority_emojis = config.options.priority_emojis
          local label = issue.priority.label
          local key = label:lower()
          local emoji = priority_emojis[key] or priority_emojis['default']
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
