local M = {}

local config = require("mantis.config")
local api = require("mantis.api")
local current_host = nil
local current_page = 1
local hosts = config.options.hosts

local function _set_host(host)
  current_host = host
end

local function _mantis()
  if current_host == nil then
    return
  end
  return api.new(current_host)
end

-- view MantisBT issues table
function M.view_issues(page)
  local page_size = config.options.view_issues.page_size
  local ViewIssues = require("mantis.ui.view_issues")
  local res = _mantis().get_issues(page, page_size)
  local issues = (res and res.issues) or {}
  local has_prev_page = (issues and page ~= 1 and true) or false
  local has_next_page = (issues and #issues == page_size and true) or false

  -- show view issues
  ViewIssues.render({
    page = page,
    host = config.options.hosts[current_host],
    options = config.options.view_issues,
    issues = issues,
    on_change_status = function(id, cb)
      M.change_status(id, cb)
    end,
    has_prev_page = has_prev_page,
    has_next_page = has_next_page,
  })
end

-- change the status of a MantisBT issue
function M.change_status(id, cb)
  local statuses = {
    "new",
    "feedback",
    "acknowledged",
    "confirmed",
    "resolved",
    "closed",
  }
  vim.ui.select(statuses, { prompt = "Select a status" }, function(status)
    local updated_status = _mantis():update_issue(id, {
      status = {
        name = status
      }
    })

    if cb then
      cb(updated_status)
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
    M.view_issues(current_page)
    return
  end

  -- multiple hosts, open select UI
  HostSelect.render({
    title = "Select MantisBT Host",
    options = config.options.selector,
    items = hosts,
    on_submit = function(id)
      _set_host(id)
      M.view_issues(current_page)
    end,
  })
end

return M
