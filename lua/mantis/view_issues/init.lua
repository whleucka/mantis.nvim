local M = {}

local ui = require("mantis.ui")
local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local util = require("mantis.util")
local options = config.options.view_issues
local helper = require("mantis.view_issues.helper")

local function get_current_filter()
  return state.current_filter or options.default_filter or 'all'
end

local signal = n.create_signal({
  show_help = false,
  selected = nil,
  mode = get_current_filter(),
  grouped = true,
  issue_nodes = {},
})

local renderer = n.create_renderer({
  width = options.ui.width,
  height = options.ui.height,
})

local issues_cache = {} -- store the fetched issues

local function build_signal_nodes()
  local grouped = signal.grouped:get_value()
  signal.issue_nodes = helper.build_nodes(issues_cache, grouped)
end

-- Update a single issue in cache and rebuild nodes (avoids API re-fetch)
local function update_cache_issue(updated_issue)
  for i, issue in ipairs(issues_cache) do
    if issue.id == updated_issue.id then
      issues_cache[i] = updated_issue
      break
    end
  end
  table.sort(issues_cache, function(a, b)
    return a.updated_at > b.updated_at
  end)
  build_signal_nodes()
end

-- Remove an issue from cache and rebuild nodes
local function remove_cache_issue(issue_id)
  for i, issue in ipairs(issues_cache) do
    if issue.id == issue_id then
      table.remove(issues_cache, i)
      break
    end
  end
  build_signal_nodes()
end

local function fetch_issues(page)
  local ok, res = false, nil
  local mode = signal.mode:get_value()
  if mode == 'all' then
    ok, res = state.api:get_issues(options.limit, page)
  elseif mode == 'monitored' then
    ok, res = state.api:get_monitored_issues(options.limit, page)
  elseif mode == 'assigned' then
    ok, res = state.api:get_assigned_issues(options.limit, page)
  elseif mode == 'unassigned' then
    ok, res = state.api:get_unassigned_issues(options.limit, page)
  elseif mode == 'reported' then
    ok, res = state.api:get_reported_issues(options.limit, page)
  end
  return ok, res
end

local function load_issues()
  local ok, res = fetch_issues(state.page)
  if ok and res and res.issues then
    issues_cache = res.issues
    build_signal_nodes()
  end
end

local function update_issue(component, issue_id, issue_data)
  local ok, res = state.api:update_issue(issue_id, issue_data)
  if ok and res and #res.issues > 0 then
    update_cache_issue(res.issues[1])
  end
end

local function update_issue_options(component, issue, property_name, property_options)
  local options_to_show = property_options
  local prompt_opts = {
    prompt = "Select a " .. property_name,
    format_item = function(item)
      return item.name
    end,
  }

  -- categories are fetched from the issue project id
  if property_name == 'category' then
    local ok, categories = state.api:get_project_categories(issue.project.id)
    if not ok then
      return
    end
    options_to_show = categories
    prompt_opts.format_item = function(item)
      return item.name
    end
  end

  -- options are presented to the user
  vim.ui.select(options_to_show, prompt_opts, function(choice)
    if not choice then
      return
    end

    local choice_name = (type(choice) == "table") and choice.name or choice
    local data = {}
    data[property_name] = { name = choice_name }

    -- if the status is resolved or closed, we will update the issue resolution
    if property_name == 'status' and (choice.name == 'resolved' or choice.name == 'closed') then
      vim.ui.select(config.options.issue_resolution_options, {
        prompt = "Select a resolution",
        format_item = function(item)
          return item.name
        end,
      }, function(resolution_choice)
        if not resolution_choice then
          return
        end
        data['resolution'] = { id = resolution_choice.id }
        update_issue(component, issue.id, data)
      end)
    else
      update_issue(component, issue.id, data)
    end
  end)
end

local function add_note(issue_id)
  ui.add_note(issue_id, function()
    -- fetch only the updated issue instead of all issues
    local ok, res = state.api:get_issue(issue_id)
    if ok and res and res.issues and res.issues[1] then
      update_cache_issue(res.issues[1])
    end
  end)
end

local function create_issue()
  local ok, res = state.api:get_all_projects()
  if not ok or #res.projects == 0 then
    return
  end
  local projects = res.projects
  vim.ui.select(projects, {
      prompt = "Select a project",
      format_item = function(item)
        return item.name
      end
    },
    function(choice)
      if not choice then return end
      ui.create_issue(choice.id)
      renderer:close()
    end
  )
end

local function change_page(direction)
  local new_page = state.page + direction
  if new_page <= 0 then
    return
  end

  local ok, res = fetch_issues(new_page)
  if ok and res and res.issues and #res.issues > 0 then
    state.page = new_page
    issues_cache = res.issues
    build_signal_nodes()
  else
    vim.notify("No more issues on the next page.", vim.log.levels.INFO)
  end
end

local function delete_issue(issue_id)
  vim.ui.input({ prompt = 'Are you sure you want to delete issue #' .. issue_id .. '? (y/n) ', default = 'n' },
    function(input)
      if input and input:lower() == 'y' then
        local ok, _ = state.api:delete_issue(issue_id)
        if ok then
          vim.notify('Issue #' .. issue_id .. ' deleted.', vim.log.levels.INFO)
          remove_cache_issue(issue_id)
        else
          vim.notify('Failed to delete issue #' .. issue_id, vim.log.levels.ERROR)
        end
      else
        vim.notify('Deletion cancelled.', vim.log.levels.INFO)
      end
    end)
end

local function filter_view()
  vim.ui.select(config.options.issue_filter_options, {
    prompt = "Select an issue filter",
  }, function(choice)
    if not choice then
      return
    end

    signal.mode = choice
    state.current_filter = choice -- persist filter across sessions
    load_issues()
  end)
end

local function assign_user(component, project_id, issue_id)
  local ok, users_data = state.api:get_project_users(project_id)
  if not ok then
    return
  end

  vim.ui.select(users_data.users, {
    prompt = "Select a user to assign",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then
      return
    end

    local data = {
      handler = { name = choice.name }
    }
    local res_ok, res = state.api:update_issue(issue_id, data)
    if res_ok and res and #res.issues > 0 then
      update_cache_issue(res.issues[1])
    end
  end)
end

local function change_summary(issue_id, summary)
  local new_summary = vim.fn.input("New summary: ", summary)
  if not new_summary or new_summary == "" then
    return
  end

  local data = {
    summary = new_summary
  }
  local ok, res = state.api:update_issue(issue_id, data)
  if ok and res and #res.issues > 0 then
    update_cache_issue(res.issues[1])
  end
end

local function get_selected_issue()
  local issue = signal.selected:get_value()
  if not issue then
    vim.notify('No issue selected.', vim.log.levels.ERROR)
    return
  end
  return issue
end

local body = function()
  local issue_table
  local api_name = (state.api.name and state.api.name) or state.api.url

  issue_table = n.tree({
    flex = 1,
    autofocus = true,
    border_label = "MantisBT Issues [" .. api_name .. "]",
    data = signal.issue_nodes,
    on_select = function(node, component)
      if node.type == 'project' then
        local project_id = node.project.id
        local collapsed = false
        for i, id in ipairs(state.collapsed_projects) do
          if id == project_id then
            table.remove(state.collapsed_projects, i)
            collapsed = true
            break
          end
        end
        if not collapsed then
          table.insert(state.collapsed_projects, project_id)
        end
        build_signal_nodes()
      elseif node.type == 'issue' then
        -- view issue
        ui.view_issue(node.issue.id)
      end
    end,
    prepare_node = helper.prepare_node,
    on_change = function(node, component)
      if node and node.type == 'issue' then
        signal.selected = node.issue
      end
    end,
    on_mount = function(component)
      local keymap = options.keymap
      component:set_border_text("bottom", " " .. keymap.help .. " help ", "right")

      -- selection indicator using subtle background
      local bufnr = component.bufnr
      local ns_id = vim.api.nvim_create_namespace("mantis_selection")
      -- subtle background - slightly different from normal bg
      vim.api.nvim_set_hl(0, "MantisSelection", { bg = "#1e1e2a" })

      local function update_selection_indicator()
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = cursor[1] - 1
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
          line_hl_group = "MantisSelection",
        })
      end

      update_selection_indicator()
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = update_selection_indicator,
      })
      -- create issue
      vim.keymap.set("n", keymap.create_issue, function()
        create_issue()
      end, { buffer = true, nowait = true })
      -- add issue note
      vim.keymap.set("n", keymap.add_note, function()
        local issue = get_selected_issue()
        if not issue then return end
        add_note(issue.id)
      end, { buffer = true, nowait = true })
      -- open issue in browser
      vim.keymap.set("n", keymap.open_issue, function()
        local issue = get_selected_issue()
        if not issue then return end
        local url = string.format("%s/view.php?id=%d", state.api.url, issue.id)
        util.open_url(url)
      end, { buffer = true, nowait = true })
      -- change status
      vim.keymap.set("n", keymap.change_status, function()
        local issue = get_selected_issue()
        if not issue then return end
        update_issue_options(component, issue, 'status', config.options.issue_status_options)
      end, { buffer = true, nowait = true })
      -- change priority
      vim.keymap.set("n", keymap.change_priority, function()
        local issue = get_selected_issue()
        if not issue then return end
        update_issue_options(component, issue, 'priority', config.options.issue_priority_options)
      end, { buffer = true, nowait = true })
      -- change severity
      vim.keymap.set("n", keymap.change_severity, function()
        local issue = get_selected_issue()
        if not issue then return end
        update_issue_options(component, issue, 'severity', config.options.issue_severity_options)
      end, { buffer = true, nowait = true })
      -- change category
      vim.keymap.set("n", keymap.change_category, function()
        local issue = get_selected_issue()
        if not issue then return end
        update_issue_options(component, issue, 'category', nil) -- categories fetched from API
      end, { buffer = true, nowait = true })
      -- change summary
      vim.keymap.set("n", keymap.change_summary, function()
        local issue = get_selected_issue()
        if not issue then return end
        change_summary(issue.id, issue.summary)
      end, { buffer = true, nowait = true })
      -- assign issue
      vim.keymap.set("n", keymap.assign_issue, function()
        local issue = get_selected_issue()
        if not issue then return end
        assign_user(component, issue.project.id, issue.id)
      end, { buffer = true, nowait = true })
      -- filter
      vim.keymap.set("n", keymap.filter, function()
        filter_view()
      end, { buffer = true, nowait = true })
      -- delete issue
      vim.keymap.set("n", keymap.delete_issue, function()
        local issue = get_selected_issue()
        if not issue then return end
        delete_issue(issue.id)
      end, { buffer = true, nowait = true })
      -- show help
      vim.keymap.set("n", keymap.help, function()
        signal.show_help = not signal.show_help:get_value()
      end, { buffer = true, nowait = true })
      -- toggle group by project
      vim.keymap.set("n", keymap.toggle_group, function()
        signal.grouped = not signal.grouped:get_value()
        build_signal_nodes()
        local status = signal.grouped:get_value() and "on" or "off"
        vim.notify("Group by project: " .. status, vim.log.levels.INFO)
      end, { buffer = true, nowait = true })
      -- refresh
      vim.keymap.set("n", keymap.refresh, function()
        load_issues()
        vim.notify("Issues refreshed.", vim.log.levels.INFO)
      end, { buffer = true, nowait = true })
      -- prev page
      vim.keymap.set("n", keymap.prev_page, function()
        change_page(-1)
      end, { buffer = true, nowait = true })
      -- next_page
      vim.keymap.set("n", keymap.next_page, function()
        change_page(1)
      end, { buffer = true, nowait = true })
      -- quit
      vim.keymap.set({ "n", "i" }, keymap.quit, function()
        renderer:close()
      end, { buffer = true, nowait = true })
    end,
  })

  local help = n.paragraph({
    hidden = signal.show_help:negate(),
    lines = helper.get_help(),
    align = "center"
  })

  return n.rows(issue_table, help)
end

-- initial load
load_issues()

function M.render()
  -- sync signal mode with persisted filter
  signal.mode = get_current_filter()
  load_issues()
  renderer:render(body)
end

return M
