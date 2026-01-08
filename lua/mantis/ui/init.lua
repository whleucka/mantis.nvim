local M = {}

local config = require('mantis.config')
local hosts = config.options.hosts
local api = nil

local function _set_api(host)
  api = require("mantis.api").new(host)
end

function M.view_issues()
  if api == nil then
    return
  end
  local ViewIssues = require("mantis.ui.view_issues")
  local page_size = config.options.view_issues.per_page
  local res = api.get_issues(page_size)
  local issues = (res and res.issues) or {}

  -- show view issues
  ViewIssues.render({
    issues = issues
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
    _set_api(host)
    M.view_issues()
    return
  end

  -- multiple hosts, open select UI
  HostSelect.render({
    hosts = hosts,
    on_submit = function(host)
      -- store the host table
      _set_api(host)
      M.view_issues()
    end,
  })
end

return M
