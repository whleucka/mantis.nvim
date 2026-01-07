local M = {}

local config = require('mantis.config')
local hosts = config.get_hosts()
local host = nil

local function _set_host(selected_host)
  host = selected_host
end

function M.show_assigned_issues()
  print("Selected host", host)
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
    _set_host(host)
    M.show_assigned_issues()
    return
  end

  -- multiple hosts, open select UI
  HostSelect.render({
    hosts = hosts,
    on_submit = function(host)
      -- store the host table
      _set_host(host)
      M.show_assigned_issues()
    end,
  })
end

return M
