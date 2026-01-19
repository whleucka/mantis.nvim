local M = {}

local state = require("mantis.state")
local config = require("mantis.config")
local api = require("mantis.api")
local helper = require("mantis.select_host.helper")

local function set_host(host)
  state.api = api.new(host)
  if state.api then
    -- load the mantis statuses, severities, priorities ... 
    local config_data = state.api:get_config({ "status_enum_string", "severity_enum_string", "priority_enum_string" })
    if config_data and config_data.configs then
      for _, c in ipairs(config_data.configs) do
        if c.option == "status_enum_string" then
          config.options.issue_status_options = helper.parse_enum_table(c.value)
        elseif c.option == "severity_enum_string" then
          config.options.issue_severity_options = helper.parse_enum_table(c.value)
        elseif c.option == "priority_enum_string" then
          config.options.issue_priority_options = helper.parse_enum_table(c.value)
        end
      end
    end
  end
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
