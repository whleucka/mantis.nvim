local M = {}

local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local options = config.options.view_issues
local helper = require("mantis.view_issues.helper")

local signal = n.create_signal({
  selected = nil,
  mode = 'all',
  issue_nodes = {},
})

local renderer = n.create_renderer({
  width = options.ui.width,
  height = options.ui.height,
})

local function refresh(component)
  local tree = component:get_tree()
  tree:render()
end

local issues_cache = {} -- store the fetched issues

local function build_and_refresh()
  signal.issue_nodes = helper.build_nodes(issues_cache)
end

local function load_issues()
  local res = {}
  local mode = signal.mode:get_value()
  if mode == 'all' then
    res = state.api:get_issues(options.limit, state.page)
  elseif mode == 'monitored' then
    res = state.api:get_monitored_issues(options.limit, state.page)
  elseif mode == 'assigned' then
    res = state.api:get_assigned_issues(options.limit, state.page)
  elseif mode == 'unassigned' then
    res = state.api:get_unassigned_issues(options.limit, state.page)
  end
  if res and res.issues then
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

  vim.ui.select(property_options, {
    prompt = "Select a " .. property_name,
  }, function(choice)
    if not choice then
      return
    end
    local data = {}
    data[property_name] = { name = choice }
    local res = state.api:update_issue(issue.id, data)
    if res and #res.issues > 0 then
      local updated_issue = res.issues[1]
      node.issue = updated_issue
      -- a full refresh is required to re-sort the issues by updated_at
      load_issues()
    end
  end)
end

local function change_page(direction)
  local new_page = state.page + direction
  if new_page <= 0 then
    return
  end

  local res = state.api:get_issues(options.limit, new_page)
  if res and res.issues and #res.issues > 0 then
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
    border_label = "MantisBT Issues",
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
        -- nothing to do here for now
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
  return n.rows(issue_table)
end

-- initial load
load_issues()

function M.render()
  renderer:render(body)
end

return M
