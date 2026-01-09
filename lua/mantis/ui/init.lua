local M = {}

local config = require('mantis.config')
local current_host = nil
local hosts = config.options.hosts
local api = require("mantis.api")
local mantis = nil
local page_size = config.options.view_issues.page_size

local function _set_host(host)
  current_host = host
  mantis = api.new(host)
end

function M.view_issue(id)
  if mantis == nil then
    return
  end

  -- local ViewIssue = require("mantis.ui.view_issue")

  -- call it with : so self is passed
  local res = mantis:get_issue(id)
  local issue = (res and res.issues[1]) or {}
  print(vim.inspect(issue))

  -- ViewIssue.render({
  --   host = current_host,
  --   issue = issue,
  -- })
end

function M.view_issues(page, assigned)
  if assigned == nil then
    assigned = false
  end
  if mantis == nil then
    return
  end

  local ViewIssues = require("mantis.ui.view_issues")
  local res = (assigned and mantis.get_my_assigned_issues(page, page_size)) or mantis.get_issues(page, page_size)
  local issues = (res and res.issues) or {}
  local has_prev_page = (issues and page ~= 1 and true) or false
  local has_next_page = (issues and #issues == page_size and true) or false

  -- show view issues
  ViewIssues.render({
    host = current_host,
    url = config.options.hosts[current_host].url,
    assigned = assigned,
    issues = issues,
    has_prev_page = has_prev_page,
    has_next_page = has_next_page,
    on_view_issue = function(id)
      M.view_issue(id)
    end,
    on_view_issues = function()
      M.view_issues(1)
    end,
    on_assigned_issues = function()
      M.view_issues(1, true)
    end
  })
end

function M.host_select()
  local HostSelect = require("mantis.ui.host_select")
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
    M.view_issues(1)
    return
  end

  -- multiple hosts, open select UI
  HostSelect.render({
    hosts = hosts,
    on_submit = function(host)
      -- store the host table
      _set_host(host)
      M.view_issues(1)
    end,
  })
end

return M
