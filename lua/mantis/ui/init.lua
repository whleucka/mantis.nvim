local M = {}

local config = require('mantis.config')
local hosts = config.get_hosts()
local api = nil

local function _set_api(host)
  api = require("mantis.api").new(host)
end

function M.view_issues()
  if api == nil then
    return
  end
  local ViewIssues = require("mantis.ui.view_issues")
  local res = api.get_issues()

  -- show view issues
  ViewIssues.render({
    issues = res.issues
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
    local _, host = next(hosts)
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
