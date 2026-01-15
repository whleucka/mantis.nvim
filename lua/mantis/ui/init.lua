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
    res = _mantis():get_project_users(choice.id)
    local users = (res and res.users) or {}

    -- show create issue
    CreateIssue.render({
      project = choice,
      users = users,
      options = config.options.create_issue,
      on_submit = function(new_issue)
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
  local issues = (res and res.issues) or {}

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
      M.prev_page(cb)
    end,
    on_next_page = function(cb)
      M.next_page(cb)
    end,
    on_refresh = function(cb)
      M.refresh(cb)
    end,
  })
end

-- refresh issues
function M.refresh(cb)
  local res = _mantis():get_issues(page_size, current_page)
  local issues = (res and res.issues) or {}
  if next(issues) ~= nil and cb then
    vim.notify("MantisBT issues refreshed", vim.log.levels.INFO)
    cb(issues)
  end
end

-- previous page of issues
function M.prev_page(cb)
  local prev_page = current_page - 1
  if prev_page < 1 then return end
  local res = _mantis():get_issues(page_size, prev_page)
  local issues = (res and res.issues) or {}
  if next(issues) ~= nil and cb then
    current_page = prev_page
    cb(issues)
  end
end

-- next page of issues
function M.next_page(cb)
  local next_page = current_page + 1
  local res = _mantis():get_issues(page_size, next_page)
  local issues = (res and res.issues) or {}
  if next(issues) ~= nil and cb then
    current_page = next_page
    cb(issues)
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
    res = _mantis():update_issue(issue_id, {
      handler = {
        name = name
      }
    })

    if name and cb then
      local issue = (res and res.issues[1]) or {}
      cb(issue)
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
    local res = _mantis():update_issue(issue_id, {
      status = {
        name = status
      }
    })

    if status and cb then
      local issue = (res and res.issues[1]) or {}
      cb(issue)
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
