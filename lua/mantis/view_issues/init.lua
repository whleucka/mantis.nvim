local M = {}

local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local options = config.options.view_issues
local helper = require("mantis.view_issues.helper")
local util = require("mantis.util")

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
    signal.issue_nodes = helper.build_nodes(res.issues)
  end
end

local issue_table = n.tree({
  flex = 1,
  autofocus = true,
  border_label = "MantisBT Issues",
  data = signal.issue_nodes,
  on_select = function(node, component)
    if node.type == 'project' then
    elseif node.type == 'issue' then
    end
  end,
  prepare_node = helper.prepare_node,
  on_change = function(node, component)
    local keymap = options.keymap
    if node.type == 'issue' then
      signal.selected = node.issue
      -- change status
      vim.keymap.set("n", keymap.change_status, function()
        local issue = signal.selected:get_value()
        vim.ui.select(config.options.issue_status_options, {
          prompt = "Select a status",
        }, function(choice)
          if not choice then
            return
          end
          local res = state.api:update_issue(issue.id, {
            status = {
              name = choice
            }
          })
          if res and #res.issues > 0 then
            local updated_issue = res.issues[1]
            node.issue = updated_issue
            refresh(component)
          end
        end)
      end, { buffer = true })
      -- prev page
      vim.keymap.set("n", keymap.prev_page, function()
        local prev_page = state.page - 1
        if prev_page > 0 then
          local res = state.api:get_issues(options.limit, prev_page)
          if res and #res.issues > 0 then
            state.page = prev_page
            signal.issue_nodes = helper.build_nodes(res.issues)
            refresh(component)
          end
        end
      end, { buffer = true })
      -- next_page
      vim.keymap.set("n", keymap.next_page, function()
        local next_page = state.page + 1
        local res = state.api:get_issues(options.limit, next_page)
        if res and #res.issues == 1 then
          state.page = next_page
          signal.issue_nodes = helper.build_nodes(res.issues)
          refresh(component)
        end
      end, { buffer = true })
    end
  end,
})

local body = function()
  return n.rows(
    issue_table
  )
end

-- initial load
load_issues()

function M.render()
  renderer:render(body)
end

return M
