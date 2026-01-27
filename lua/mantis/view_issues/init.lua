local M = {}

local ui = require("mantis.ui")
local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local util = require("mantis.util")
local helper = require("mantis.view_issues.helper")

local function get_current_filter()
  local options = config.options.view_issues
  return state.current_filter or options.default_filter or 'all'
end

function M.render()
  local options = config.options.view_issues

  local signal = n.create_signal({
    selected = nil,
    mode = get_current_filter(),
    grouped = state.grouped,
    issue_nodes = {},
  })

  local renderer = n.create_renderer({
    width = util.resolve_dimension(options.ui.width, vim.o.columns, options.ui.max_width),
    height = util.resolve_dimension(options.ui.height, vim.o.lines, options.ui.max_height),
  })

  local issues_cache = {}

  local function build_signal_nodes()
    local grouped = signal.grouped:get_value()
    signal.issue_nodes = helper.build_nodes(issues_cache, grouped)
  end

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

  local function load_issues(show_loading)
    local ok, res
    if show_loading then
      ok, res = util.with_loading("Loading issues", function()
        return fetch_issues(state.page)
      end)
    else
      ok, res = fetch_issues(state.page)
    end
    if ok and res and res.issues then
      issues_cache = res.issues
      build_signal_nodes()
    end
  end

  local function update_issue(issue_id, issue_data)
    local ok, res = state.api:update_issue(issue_id, issue_data)
    if ok and res and #res.issues > 0 then
      update_cache_issue(res.issues[1])
    end
  end

  local function update_issue_options(issue, property_name, property_options)
    local options_to_show = property_options
    local prompt_opts = {
      prompt = "Select a " .. property_name,
      format_item = function(item)
        return item.name
      end,
    }

    if property_name == 'category' then
      local ok, categories = state.get_project_categories(issue.project.id)
      if not ok then
        return
      end
      options_to_show = categories
      prompt_opts.format_item = function(item)
        return item.name
      end
    end

    vim.ui.select(options_to_show, prompt_opts, function(choice)
      if not choice then
        return
      end

      local choice_name = (type(choice) == "table") and choice.name or choice
      local data = {}
      data[property_name] = { name = choice_name }

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
          update_issue(issue.id, data)
        end)
      else
        update_issue(issue.id, data)
      end
    end)
  end

  local function add_note(issue_id)
    ui.add_note(issue_id, function()
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

    local ok, res = util.with_loading("Loading page " .. new_page, function()
      return fetch_issues(new_page)
    end)
    if ok and res and res.issues and #res.issues > 0 then
      state.page = new_page
      state.clear_selection() -- Clear selection on page change
      issues_cache = res.issues
      build_signal_nodes()
    else
      vim.notify("No more issues on the next page.", vim.log.levels.INFO)
    end
  end

  -- Selection functions
  local function toggle_select()
    local issue = signal.selected:get_value()
    if not issue then
      vim.notify("No issue selected.", vim.log.levels.WARN)
      return
    end
    state.toggle_selection(issue.id)
    build_signal_nodes()
  end

  local function select_all_issues()
    for _, issue in ipairs(issues_cache) do
      state.selected_issues[issue.id] = true
    end
    build_signal_nodes()
    vim.notify("Selected " .. #issues_cache .. " issues.", vim.log.levels.INFO)
  end

  local function clear_selection()
    state.clear_selection()
    build_signal_nodes()
    vim.notify("Selection cleared.", vim.log.levels.INFO)
  end

  -- Helper to get issues from selected IDs
  local function get_selected_issues_from_cache()
    local selected = {}
    local ids = state.get_selected_ids()
    for _, id in ipairs(ids) do
      for _, issue in ipairs(issues_cache) do
        if issue.id == id then
          table.insert(selected, issue)
          break
        end
      end
    end
    return selected
  end

  -- Check if all selected issues are from the same project
  local function validate_same_project(selected_issues)
    if #selected_issues == 0 then
      return false, nil
    end
    local project_id = selected_issues[1].project.id
    for _, issue in ipairs(selected_issues) do
      if issue.project.id ~= project_id then
        return false, nil
      end
    end
    return true, project_id
  end

  -- Batch operation helper
  local function batch_update(selected_issues, data_fn, on_complete)
    local success_count = 0
    local fail_count = 0
    local total = #selected_issues

    for i, issue in ipairs(selected_issues) do
      local issue_data = data_fn(issue)
      if issue_data then
        local ok, res = state.api:update_issue(issue.id, issue_data)
        if ok and res and #res.issues > 0 then
          update_cache_issue(res.issues[1])
          success_count = success_count + 1
        else
          fail_count = fail_count + 1
        end
      end
    end

    state.clear_selection()
    build_signal_nodes()

    if fail_count > 0 then
      vim.notify(string.format("Updated %d/%d issues (%d failed)", success_count, total, fail_count), vim.log.levels.WARN)
    else
      vim.notify(string.format("Updated %d issues", success_count), vim.log.levels.INFO)
    end

    if on_complete then
      on_complete()
    end
  end

  -- Batch change status
  local function batch_change_status()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()

    vim.ui.select(config.options.issue_status_options, {
      prompt = string.format("Change status for %d issues", count),
      format_item = function(item) return item.name end,
    }, function(choice)
      if not choice then return end

      local function do_update(resolution_choice)
        batch_update(selected_issues, function(issue)
          local data = { status = { name = choice.name } }
          if resolution_choice then
            data.resolution = { id = resolution_choice.id }
          end
          return data
        end)
      end

      if choice.name == 'resolved' or choice.name == 'closed' then
        vim.ui.select(config.options.issue_resolution_options, {
          prompt = "Select a resolution",
          format_item = function(item) return item.name end,
        }, function(resolution_choice)
          if not resolution_choice then return end
          do_update(resolution_choice)
        end)
      else
        do_update(nil)
      end
    end)
  end

  -- Batch change priority
  local function batch_change_priority()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()

    vim.ui.select(config.options.issue_priority_options, {
      prompt = string.format("Change priority for %d issues", count),
      format_item = function(item) return item.name end,
    }, function(choice)
      if not choice then return end

      batch_update(selected_issues, function(issue)
        return { priority = { name = choice.name } }
      end)
    end)
  end

  -- Batch change severity
  local function batch_change_severity()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()

    vim.ui.select(config.options.issue_severity_options, {
      prompt = string.format("Change severity for %d issues", count),
      format_item = function(item) return item.name end,
    }, function(choice)
      if not choice then return end

      batch_update(selected_issues, function(issue)
        return { severity = { name = choice.name } }
      end)
    end)
  end

  -- Batch change category (project-specific)
  local function batch_change_category()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()
    local same_project, project_id = validate_same_project(selected_issues)
    if not same_project then
      vim.notify("Cannot batch change category: selected issues are from different projects.", vim.log.levels.ERROR)
      return
    end

    local ok, categories = state.get_project_categories(project_id)
    if not ok then
      vim.notify("Failed to load categories.", vim.log.levels.ERROR)
      return
    end

    vim.ui.select(categories, {
      prompt = string.format("Change category for %d issues", count),
      format_item = function(item) return item.name end,
    }, function(choice)
      if not choice then return end

      batch_update(selected_issues, function(issue)
        return { category = { name = choice.name } }
      end)
    end)
  end

  -- Batch assign user (project-specific)
  local function batch_assign_user()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()
    local same_project, project_id = validate_same_project(selected_issues)
    if not same_project then
      vim.notify("Cannot batch assign: selected issues are from different projects.", vim.log.levels.ERROR)
      return
    end

    local ok, users = state.get_project_users(project_id)
    if not ok then
      vim.notify("Failed to load users.", vim.log.levels.ERROR)
      return
    end

    vim.ui.select(users, {
      prompt = string.format("Assign user to %d issues", count),
      format_item = function(item) return item.name end,
    }, function(choice)
      if not choice then return end

      batch_update(selected_issues, function(issue)
        return { handler = { name = choice.name } }
      end)
    end)
  end

  -- Batch delete
  local function batch_delete()
    local count = state.selection_count()
    if count == 0 then
      vim.notify("No issues selected.", vim.log.levels.WARN)
      return
    end

    local selected_issues = get_selected_issues_from_cache()
    local ids = {}
    for _, issue in ipairs(selected_issues) do
      table.insert(ids, "#" .. issue.id)
    end

    vim.ui.input({
      prompt = string.format('Delete %d issues (%s)? Type "yes" to confirm: ', count, table.concat(ids, ", ")),
    }, function(input)
      if not input or input:lower() ~= "yes" then
        vim.notify("Batch delete cancelled.", vim.log.levels.INFO)
        return
      end

      local success_count = 0
      local fail_count = 0

      for _, issue in ipairs(selected_issues) do
        local ok, _ = state.api:delete_issue(issue.id)
        if ok then
          remove_cache_issue(issue.id)
          success_count = success_count + 1
        else
          fail_count = fail_count + 1
        end
      end

      state.clear_selection()
      build_signal_nodes()

      if fail_count > 0 then
        vim.notify(string.format("Deleted %d/%d issues (%d failed)", success_count, count, fail_count), vim.log.levels.WARN)
      else
        vim.notify(string.format("Deleted %d issues", success_count), vim.log.levels.INFO)
      end
    end)
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
      state.current_filter = choice
      load_issues(false)
    end)
  end

  local function assign_user(project_id, issue_id)
    local ok, users = state.get_project_users(project_id)
    if not ok then
      return
    end

    vim.ui.select(users, {
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
    local current_node_type = nil  -- Track current node type for highlighting
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
          ui.view_issue(node.issue.id)
        end
      end,
      prepare_node = helper.prepare_node,
      on_change = function(node, component)
        current_node_type = node and node.type or nil
        if node and node.type == 'issue' then
          signal.selected = node.issue
        end
      end,
      on_mount = function(component)
        local keymap = options.keymap
        component:set_border_text("bottom", " " .. keymap.help .. " help ", "right")

        local bufnr = component.bufnr
        local ns_id = vim.api.nvim_create_namespace("mantis_selection")
        vim.api.nvim_set_hl(0, "MantisSelection", { bg = "#1e1e2a" })

        local function update_selection_indicator()
          vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
          if current_node_type == 'issue' then
            local cursor = vim.api.nvim_win_get_cursor(0)
            local line = cursor[1] - 1
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
              line_hl_group = "MantisSelection",
            })
          end
        end

        update_selection_indicator()
        vim.api.nvim_create_autocmd("CursorMoved", {
          buffer = bufnr,
          callback = update_selection_indicator,
        })

        vim.keymap.set("n", keymap.create_issue, function()
          create_issue()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.add_note, function()
          local issue = get_selected_issue()
          if not issue then return end
          add_note(issue.id)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.open_issue, function()
          local issue = get_selected_issue()
          if not issue then return end
          local url = string.format("%s/view.php?id=%d", state.api.url, issue.id)
          util.open_url(url)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.change_status, function()
          local issue = get_selected_issue()
          if not issue then return end
          update_issue_options(issue, 'status', config.options.issue_status_options)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.change_priority, function()
          local issue = get_selected_issue()
          if not issue then return end
          update_issue_options(issue, 'priority', config.options.issue_priority_options)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.change_severity, function()
          local issue = get_selected_issue()
          if not issue then return end
          update_issue_options(issue, 'severity', config.options.issue_severity_options)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.change_category, function()
          local issue = get_selected_issue()
          if not issue then return end
          update_issue_options(issue, 'category', nil)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.change_summary, function()
          local issue = get_selected_issue()
          if not issue then return end
          change_summary(issue.id, issue.summary)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.assign_issue, function()
          local issue = get_selected_issue()
          if not issue then return end
          assign_user(issue.project.id, issue.id)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.filter, function()
          filter_view()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.delete_issue, function()
          local issue = get_selected_issue()
          if not issue then return end
          delete_issue(issue.id)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.help, function()
          local view_help = require("mantis.view_help")
          view_help.render()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.toggle_group, function()
          signal.grouped = not signal.grouped:get_value()
          state.grouped = signal.grouped:get_value()
          build_signal_nodes()
          local status = signal.grouped:get_value() and "on" or "off"
          vim.notify("Group by project: " .. status, vim.log.levels.INFO)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.refresh, function()
          load_issues(true)
          vim.notify("Issues refreshed.", vim.log.levels.INFO)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.prev_page, function()
          change_page(-1)
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.next_page, function()
          change_page(1)
        end, { buffer = true, nowait = true })

        -- Selection keybindings
        vim.keymap.set("n", keymap.toggle_select, function()
          toggle_select()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.select_all, function()
          select_all_issues()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.clear_selection, function()
          clear_selection()
        end, { buffer = true, nowait = true })

        -- Batch operation keybindings
        vim.keymap.set("n", keymap.batch_status, function()
          batch_change_status()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.batch_priority, function()
          batch_change_priority()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.batch_severity, function()
          batch_change_severity()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.batch_category, function()
          batch_change_category()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.batch_assign, function()
          batch_assign_user()
        end, { buffer = true, nowait = true })

        vim.keymap.set("n", keymap.batch_delete, function()
          batch_delete()
        end, { buffer = true, nowait = true })

        vim.keymap.set({ "n", "i" }, keymap.quit, function()
          renderer:close()
        end, { buffer = true, nowait = true })
      end,
    })

    return issue_table
  end

  load_issues(false)  -- no loading indicator on initial load
  renderer:render(body)
end

return M
