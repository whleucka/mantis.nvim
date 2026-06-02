local M = {}

local state = require("mantis.state")
local config = require("mantis.config")
local api = require("mantis.api")

local function parse_enum(value)
  return type(value) == "table" and value or {}
end

--- Switch the active host and load its enum config without blocking.
--- `on_complete` is invoked once the config request settles (or immediately if
--- the host could not be initialized).
---@param host table host configuration
---@param on_complete? function called after config is loaded
local function set_host(host, on_complete)
  state.api = api.new(host)
  state.clear_caches() -- clear project caches when switching hosts
  if not state.api then
    if on_complete then on_complete() end
    return
  end

  -- load the mantis statuses, severities, priorities ...
  state.api:get_config(
    { "status_enum_string", "severity_enum_string", "priority_enum_string", "resolution_enum_string", "reproducibility_enum_string" },
    function(ok, config_data)
      if ok and config_data and config_data.configs then
        for _, c in ipairs(config_data.configs) do
          if c.option == "status_enum_string" then
            config.options.issue_status_options = parse_enum(c.value)
          elseif c.option == "severity_enum_string" then
            config.options.issue_severity_options = parse_enum(c.value)
          elseif c.option == "priority_enum_string" then
            config.options.issue_priority_options = parse_enum(c.value)
          elseif c.option == "resolution_enum_string" then
            config.options.issue_resolution_options = parse_enum(c.value)
          elseif c.option == "reproducibility_enum_string" then
            config.options.issue_reproducibility_options = parse_enum(c.value)
          end
        end
      end
      if on_complete then on_complete() end
    end
  )
end

function M.render(on_complete)
  local hosts = config.options.hosts
  local count = vim.tbl_count(hosts)

  -- auto-select if only one host
  if count == 1 then
    local _, host = next(hosts)
    set_host(host, on_complete)
    return
  end

  -- sort a copy so we don't mutate the user's config
  local sorted_hosts = vim.list_extend({}, hosts)
  table.sort(sorted_hosts, function(a, b)
    local a_field = a.name or a.url
    local b_field = b.name or b.url
    return a_field < b_field
  end)

  -- select a host
  vim.ui.select(sorted_hosts, {
    prompt = "Select a MantisBT host",
    format_item = function(item)
      return item.name or item.url
    end,
  }, function(choice)
    if not choice then
      return
    end

    set_host(choice, on_complete)
  end)
end

return M
