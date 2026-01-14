local M = {}

local util = require("mantis.util")
local config = require("mantis.config")
local api = require("mantis.api")
local current_host = nil
local current_page = 1
local hosts = config.options.hosts
local page_size = config.options.view_issues.limit

local function _set_host(host)
  current_host = host
end

local function _mantis()
  if current_host == nil then
    return
  end
  return api.new(current_host)
end

-- create a new issue
function M.create_issue()
  local CreateIssue = require("mantis.ui.create_issue")
  local res = _mantis():get_all_projects()
  local projects = (res and res.projects) or {}

  local options = {}
  for _, project in ipairs(projects) do
    table.insert(options, project)
  end

  vim.ui.select(options, {
    prompt = "Select a project",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then return end
    local res = _mantis():get_project_users(choice.id)
    local users = (res and res.users) or {}

    -- show create issue
    CreateIssue.render({
      project = choice,
      users = users,
      options = config.options.create_issue,
      on_submit = function(new_issue)
        util.print(new_issue)
        _mantis():create_issue(new_issue)
        M.view_issues()
      end
    })
  end)
end

-- view issues table
function M.view_issues()
  local ViewIssues = require("mantis.ui.view_issues")
  local res = _mantis():get_issues(page_size, current_page)
  local next_page = _mantis():get_issues(page_size, current_page + 1)
  local issues = (res and res.issues) or {}
  local _issues = (next_page and next_page.issues) or {}
  local has_prev_page = (issues and current_page ~= 1 and true) or false
  local has_next_page = (issues and #_issues > 0 and true) or false

  -- show view issues
  ViewIssues.render({
    page = current_page,
    host = config.options.hosts[current_host],
    options = config.options.view_issues,
    issues = issues,
    on_create_issue = function()
      M.create_issue()
    end,
    on_change_status = function(issue_id, cb)
      M.change_status(issue_id, cb)
    end,
    on_assign_user = function(issue_id, project_id, cb)
      M.assign_user(issue_id, project_id, cb)
    end,
    on_prev_page = function(cb)
      if has_prev_page then
        M.prev_page(cb)
      end
    end,
    on_next_page = function(cb)
      if has_next_page then
        M.next_page(cb)
      end
    end,
    on_refresh = function(cb)
      M.refresh(cb)
    end,
    has_prev_page = has_prev_page,
    has_next_page = has_next_page,
  })
end

-- refresh issues
function M.refresh(cb)
  local res = _mantis():get_issues(page_size, current_page)
  local issues = (res and res.issues) or {}
  if issues and cb then
    vim.notify("MantisBT issues refreshed", vim.log.levels.INFO)
    M.view_issues()
    cb()
  end
end

-- previous page of issues
function M.prev_page(cb)
  local prev_page = current_page - 1
  local res = _mantis():get_issues(page_size, prev_page)
  local issues = (res and res.issues) or {}
  if issues and cb then
    current_page = prev_page
    M.view_issues()
    cb()
  end
end

-- next page of issues
function M.next_page(cb)
  local next_page = current_page + 1
  local res = _mantis():get_issues(page_size, next_page)
  local issues = (res and res.issues) or {}
  if issues and cb then
    current_page = next_page
    M.view_issues()
    cb()
  end
end

-- assign a user to a MantisBT issue
function M.assign_user(issue_id, project_id, cb)
  local res = _mantis():get_project_users(project_id)
  local users = (res and res.users) or {}
  local options = { 'n/a' }
  for _, user in ipairs(users) do
    table.insert(options, user.name)
  end
  vim.ui.select(options, { prompt = "Select a user" }, function(name)
    if not name then return end
    name = (name == 'n/a' and '') or name
    _mantis():update_issue(issue_id, {
      handler = {
        name = name
      }
    })

    if name and cb then
      M.view_issues()
      cb()
    end
  end)
end

-- change the status of a MantisBT issue
function M.change_status(issue_id, cb)
  local options = {
    "new",
    "feedback",
    "acknowledged",
    "confirmed",
    "resolved",
    "closed",
  }
  vim.ui.select(options, { prompt = "Select a status" }, function(status)
    if not status then return end
    _mantis():update_issue(issue_id, {
      status = {
        name = status
      }
    })

    if status and cb then
      M.view_issues()
      cb()
    end
  end)
end

-- select a host from the config
function M.host_select()
  local HostSelect = require("mantis.ui.selector")
  local count = vim.tbl_count(hosts)

  -- no hosts
  if count == 0 then
    vim.notify("No hosts configured.", vim.log.levels.ERROR)
    return
  end

  -- only one host
  if count == 1 then
    local host, _ = next(hosts)
    _set_host(host)
    M.view_issues()
    return
  end

  -- multiple hosts, open select UI
  HostSelect.render({
    title = "Select MantisBT Host",
    options = config.options.selector,
    items = hosts,
    on_submit = function(id)
      _set_host(id)
      M.view_issues()
    end,
  })
end

return M
