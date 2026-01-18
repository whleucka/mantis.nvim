local M = {}

local state = require("mantis.state")
local config = require("mantis.config")
local api = require("mantis.api")

local function set_host(host)
  state.api = api.new(host)
end

function M.render()
  local hosts = config.options.hosts
  local count = vim.tbl_count(hosts)

  -- auto-select if only one host
  if count == 1 then
    local _, host = next(hosts)
    set_host(host)
    return
  end

  -- sort the menu
  table.sort(hosts, function(a, b)
    return a.name < b.name
  end)

  -- select a host
  vim.ui.select(hosts, {
    prompt = "Select a MantisBT host",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then
      return
    end

    set_host(choice)
  end)
end

return M
