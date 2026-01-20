local M = {}

local ui = require("mantis.ui")
local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local options = config.options.view_issues
local helper = require("mantis.view_issues.helper")

local signal = n.create_signal({
  show_help = false,
  selected = nil,
  mode = 'all',
  issue_nodes = {},
})

local renderer = n.create_renderer({
  width = options.ui.width,
  height = options.ui.height,
})

local issues_cache = {} -- store the fetched issues

local function build_and_refresh()
  signal.issue_nodes = helper.build_nodes(issues_cache)
end

local function load_issues()
  local ok, res = false, nil
  local mode = signal.mode:get_value()
  if mode == 'all' then
    ok, res = state.api:get_issues(options.limit, state.page)
  elseif mode == 'monitored' then
    ok, res = state.api:get_monitored_issues(options.limit, state.page)
  elseif mode == 'assigned' then
    ok, res = state.api:get_assigned_issues(options.limit, state.page)
  elseif mode == 'unassigned' then
    ok, res = state.api:get_unassigned_issues(options.limit, state.page)
  elseif mode == 'reported' then
    ok, res = state.api:get_reported_issues(options.limit, state.page)
  end

  if ok and res and res.issues then
    issues_cache = res.issues
    build_and_refresh()
  end
end

local function update_issue_property(issue_table, property_name, property_options)
  local node = issue_table:get_tree():get_node()
  if not (node and node.type == 'issue') then
    return
  end
  local issue = node.issue

  local options_to_show = property_options
  local prompt_opts = {
    prompt = "Select a " .. property_name,
  }

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

  vim.ui.select(options_to_show, prompt_opts, function(choice)
    if not choice then
      return
    end

    local choice_name = (type(choice) == "table") and choice.name or choice
    local data = {} 
    data[property_name] = { name = choice_name }

    local function update_issue(issue_id, issue_data)
      local ok, res = state.api:update_issue(issue_id, issue_data)
      if ok and res and #res.issues > 0 then
        local updated_issue = res.issues[1]
        node.issue = updated_issue
        -- a full refresh is required to re-sort the issues by updated_at
        load_issues()
      end
    end

    if property_name == 'status' and (choice == 'resolved' or choice == 'closed') then
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
local function change_page(direction)
  local new_page = state.page + direction
  if new_page <= 0 then
    return
  end

  local ok, res = state.api:get_issues(options.limit, new_page)
  if ok and res and res.issues and #res.issues > 0 then
    state.page = new_page
    issues_cache = res.issues -- update cache
    build_and_refresh()
  else
    vim.notify("No more issues on the next page.", vim.log.levels.INFO)
  end
end

local body = function()
  local issue_table

  issue_table = n.tree({
    flex = 1,
    autofocus = true,
    border_label = "MantisBT Issues [" .. state.api.name .. "]",
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
        build_and_refresh()
      elseif node.type == 'issue' then
        -- view issue

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
      -- add issue note
      vim.keymap.set("n", keymap.add_note, function()
        local issue = signal.selected:get_value()
        if issue and issue.id then
          ui.add_note(issue.id)
        else
          vim.notify("No issue selected.", vim.log.levels.WARN)
        end
      end, { buffer = true, nowait = true })
      -- create issue
      vim.keymap.set("n", keymap.create_issue, function()
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
      end, { buffer = true, nowait = true })
      -- open issue in browser
      vim.keymap.set("n", keymap.open_issue, function()
        local issue = signal.selected:get_value()
        local url = string.format("%s/view.php?id=%d", state.api.url, issue.id)
        vim.system({ 'xdg-open', url }, { detach = true })
      end, { buffer = true, nowait = true })
      -- show help
      vim.keymap.set("n", keymap.help, function()
        signal.show_help = not signal.show_help:get_value()
      end, { buffer = true, nowait = true })
      -- refresh
      vim.keymap.set("n", keymap.refresh, function()
        load_issues()
        vim.notify("Issues refreshed.", vim.log.levels.INFO)
      end, { buffer = true, nowait = true })
      -- change status
      vim.keymap.set("n", keymap.change_status, function()
        update_issue_property(component, 'status', config.options.issue_status_options)
      end, { buffer = true, nowait = true })
      -- change priority
      vim.keymap.set("n", keymap.change_priority, function()
        update_issue_property(component, 'priority', config.options.issue_priority_options)
      end, { buffer = true, nowait = true })
      -- change severity
      vim.keymap.set("n", keymap.change_severity, function()
        update_issue_property(component, 'severity', config.options.issue_severity_options)
      end, { buffer = true, nowait = true })
      -- change summary
      vim.keymap.set("n", keymap.change_summary, function()
        vim.schedule(function()
          local node = component:get_tree():get_node()
          if not (node and node.type == 'issue') then
            return
          end
          local issue = node.issue

          local new_summary = vim.fn.input("New summary: ", issue.summary)
          if not new_summary or new_summary == "" then
            return
          end

          local data = {
            summary = new_summary
          }
          local ok, res = state.api:update_issue(issue.id, data)
          if ok and res and #res.issues > 0 then
            local updated_issue = res.issues[1]
            node.issue = updated_issue
            load_issues()
          end
        end)
      end, { buffer = true, nowait = true })
      -- change category
      vim.keymap.set("n", keymap.change_category, function()
        update_issue_property(component, 'category', config.options.issue_category_options)
      end, { buffer = true, nowait = true })
      -- assign issue
      vim.keymap.set("n", keymap.assign_issue, function()
        vim.schedule(function()
          local node = component:get_tree():get_node()
          if not (node and node.type == 'issue') then
            return
          end
          local issue = node.issue

          local ok, users_data = state.api:get_project_users(issue.project.id)
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
            local ok, res = state.api:update_issue(issue.id, data)
            if ok and res and #res.issues > 0 then
              local updated_issue = res.issues[1]
              node.issue = updated_issue
              load_issues()
            end
          end)
        end)
      end, { buffer = true, nowait = true })
      -- filter
      vim.keymap.set("n", keymap.filter, function()
        vim.ui.select(config.options.issue_filter_options, {
          prompt = "Select an issue filter",
        }, function(choice)
          if not choice then
            return
          end

          signal.mode = choice
          load_issues()
        end)
      end, { buffer = true, nowait = true })
      -- delete issue
      vim.keymap.set("n", keymap.delete_issue, function()
        local issue = signal.selected:get_value()
        if not issue then
          vim.notify('No issue selected.', vim.log.levels.ERROR)
          return
        end

        vim.ui.input({ prompt = 'Are you sure you want to delete issue #' .. issue.id .. '? (y/n) ', default = 'n' },
          function(input)
            if input and input:lower() == 'y' then
              local ok, _ = state.api:delete_issue(issue.id)
              if ok then
                vim.notify('Issue #' .. issue.id .. ' deleted.', vim.log.levels.INFO)
                load_issues()
              else
                vim.notify('Failed to delete issue #' .. issue.id, vim.log.levels.ERROR)
              end
            else
              vim.notify('Deletion cancelled.', vim.log.levels.INFO)
            end
          end)
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
  renderer:render(body)
end

return M
