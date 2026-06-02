--- Every method accepts an optional trailing `callback`. When supplied the
--- call is non-blocking and the result is delivered via `callback(ok, res)` on
--- the main loop; when omitted the call is synchronous and returns `ok, res`.
---@alias MantisCallback fun(ok: boolean, res: table|string|nil)
---@class MantisAPI
---@field url string
---@field name string
---@field get_issue fun(self, id: number, callback?: MantisCallback): boolean?, table?
---@field get_issues fun(self, opts_or_page_size?: table|number, page?: number, callback?: MantisCallback): boolean?, table?
---@field create_issue fun(self, data: table, callback?: MantisCallback): boolean?, table?
---@field update_issue fun(self, id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field delete_issue fun(self, id: number, callback?: MantisCallback): boolean?, table?
---@field get_issue_files fun(self, issue_id: number, callback?: MantisCallback): boolean?, table?
---@field get_issue_file fun(self, issue_id: number, file_id: number, callback?: MantisCallback): boolean?, table?
---@field get_project_issues fun(self, project_id: number, callback?: MantisCallback): boolean?, table?
---@field get_project_users fun(self, project_id: number, callback?: MantisCallback): boolean?, table?
---@field get_project_categories fun(self, project_id: number, callback?: MantisCallback): boolean?, table?
---@field get_filtered_issues fun(self, filter_id: string|number, callback?: MantisCallback): boolean?, table?
---@field get_all_issues fun(self, callback?: MantisCallback): boolean?, table?
---@field get_all_projects fun(self, callback?: MantisCallback): boolean?, table?
---@field get_assigned_issues fun(self, page_size?: number, page?: number, callback?: MantisCallback): boolean?, table?
---@field get_reported_issues fun(self, page_size?: number, page?: number, callback?: MantisCallback): boolean?, table?
---@field get_monitored_issues fun(self, page_size?: number, page?: number, callback?: MantisCallback): boolean?, table?
---@field get_unassigned_issues fun(self, page_size?: number, page?: number, callback?: MantisCallback): boolean?, table?
---@field add_attachments_to_issue fun(self, issue_id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field create_issue_note fun(self, issue_id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field edit_issue_note fun(self, issue_id: number, note_id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field delete_issue_note fun(self, issue_id: number, note_id: number, callback?: MantisCallback): boolean?, table?
---@field monitor_issue fun(self, issue_id: number, callback?: MantisCallback): boolean?, table?
---@field unmonitor_issue fun(self, issue_id: number, user_id: number, callback?: MantisCallback): boolean?, table?
---@field add_tags_to_issue fun(self, issue_id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field remove_tags_from_issue fun(self, issue_id: number, tag_id: number, callback?: MantisCallback): boolean?, table?
---@field add_issue_relationship fun(self, issue_id: number, data: table, callback?: MantisCallback): boolean?, table?
---@field get_config fun(self, options: table, callback?: MantisCallback): boolean?, table?

local M = {}

local config = require('mantis.config')
local curl = require('plenary.curl')

--- Create a new MantisAPI instance
---@param host_config table|nil Host configuration with url, token/env, and optional name
---@return MantisAPI|nil
function M.new(host_config)
  if not host_config then
    vim.notify('Mantis: No host configuration provided.', vim.log.levels.ERROR)
    return nil
  end

  local instance = {}
  instance.name = host_config.name
  instance.url = host_config.url

  -- resolve token from direct value or environment variable
  if host_config.token then
    instance.token = host_config.token
  elseif host_config.env then
    instance.token = os.getenv(host_config.env)
    if not instance.token then
      vim.notify('Mantis: Environment variable "' .. host_config.env .. '" not set.', vim.log.levels.ERROR)
      return nil
    end
  end

  if not instance.url then
    vim.notify('Mantis: URL not configured for host.', vim.log.levels.ERROR)
    return nil
  end

  if not instance.token then
    vim.notify('Mantis: Token not configured for host "' .. (instance.url or 'unknown') .. '".', vim.log.levels.ERROR)
    return nil
  end

  return setmetatable(instance, { __index = M })
end

-- Curl dispatch table (avoids an if/elseif chain per request)
local curl_methods = {
  GET = curl.get,
  POST = curl.post,
  PATCH = curl.patch,
  PUT = curl.put,
  DELETE = curl.delete,
}

--- Turn a raw curl response into (ok, result).
--- Must run on the main loop (calls vim.notify); the async path guarantees
--- this by wrapping the invocation in vim.schedule.
---@param response table plenary.curl response
---@return boolean ok
---@return table|string|nil result decoded body, or error message on failure
local function process_response(response)
  if config.options.debug then
    print('Mantis API Response:')
    print('Status: ' .. tostring(response.status))
    print('Body: ' .. tostring(response.body))
  end

  if response.status < 200 or response.status >= 300 then
    local error_message = "Mantis API Error"
    if response.body and response.body ~= "" then
      local decode_ok, decoded = pcall(vim.fn.json_decode, response.body)
      if decode_ok and type(decoded) == "table" and decoded.message then
        error_message = decoded.message
      else
        error_message = response.body
      end
    end
    vim.notify('Mantis API Error: ' .. error_message, vim.log.levels.ERROR)
    return false, error_message
  end

  if response.body and response.body ~= '' then
    local decode_ok, decoded = pcall(vim.fn.json_decode, response.body)
    if decode_ok then
      return true, decoded
    else
      vim.notify('Mantis API Error: Failed to decode response body.', vim.log.levels.ERROR)
      return false, "Failed to decode response"
    end
  end

  return true, nil
end

--- Perform a request against the MantisBT REST API.
---
--- When `callback` is supplied the request is non-blocking: `callback(ok, res)`
--- is invoked on the main loop once the response arrives (or on error). When it
--- is omitted the call is synchronous and returns `ok, res` as before.
---@param endpoint string REST endpoint (relative to /api/rest/)
---@param method? string HTTP method (default 'GET')
---@param data? table optional request body (json-encoded)
---@param callback? fun(ok: boolean, res: table|string|nil) async result handler
function M:call_api(endpoint, method, data, callback)
  if self.url == nil then
    if callback then
      vim.schedule(function() callback(false, "URL not configured") end)
      return
    end
    return false, "URL not configured"
  end

  method = method or 'GET'
  local headers = {
    ['Authorization'] = self.token,
    ['Content-Type'] = 'application/json',
  }

  local url = self.url .. '/api/rest/' .. endpoint

  local opts = {
    headers = headers,
    follow_redirects = false,
  }

  if data then
    opts.body = vim.fn.json_encode(data)
  end

  if config.options.debug then
    print('Mantis API Request:')
    print('URL: ' .. url)
    print('Method: ' .. method)
    if data then
      print('Data: ' .. opts.body)
    end
  end

  local method_fn = curl_methods[method]
  if not method_fn then
    if callback then
      vim.schedule(function() callback(false, "Unsupported method " .. method) end)
      return
    end
    return false, "Unsupported method " .. method
  end

  -- Async path: hand plenary a callback. plenary invokes on_exit/callback from
  -- a libuv fast-event context, so everything that touches vim.* is deferred to
  -- the main loop with vim.schedule.
  if callback then
    opts.callback = function(response)
      vim.schedule(function()
        callback(process_response(response))
      end)
    end
    opts.on_error = function(err)
      vim.schedule(function()
        local message = (type(err) == "table" and err.message) or tostring(err)
        vim.notify('Mantis API Error: ' .. message, vim.log.levels.ERROR)
        callback(false, message)
      end)
    end
    -- plenary may still raise synchronously while spawning (e.g. curl missing).
    local spawn_ok, spawn_err = pcall(method_fn, url, opts)
    if not spawn_ok then
      vim.schedule(function()
        vim.notify('Mantis API Error: ' .. tostring(spawn_err), vim.log.levels.ERROR)
        callback(false, spawn_err)
      end)
    end
    return
  end

  -- Sync path (blocking): preserved for callers that have not been converted.
  local ok, response = pcall(method_fn, url, opts)

  if not ok then
    vim.notify('Mantis API Error: ' .. tostring(response), vim.log.levels.ERROR)
    return false, response
  end

  return process_response(response)
end

function M:get_config(options, callback)
  local query_params = {}

  for _, option in ipairs(options) do
    table.insert(query_params, 'option[]=' .. option)
  end

  local query_string = table.concat(query_params, '&')
  local endpoint = 'config'
  if query_string ~= '' then
    endpoint = endpoint .. '?' .. query_string
  end
  return self:call_api(endpoint, 'GET', nil, callback)
end

--- issues
function M:get_issue(id, callback)
  return self:call_api('issues/' .. id, 'GET', nil, callback)
end

function M:get_issues(opts_or_page_size, page, callback)
  local opts
  if type(opts_or_page_size) == 'table' then
    opts = opts_or_page_size
  else
    opts = {
      page_size = opts_or_page_size,
      page = page,
    }
  end

  opts = opts or {}
  local query_params = {}

  if opts.page_size then
    table.insert(query_params, 'page_size=' .. opts.page_size)
  end

  if opts.page then
    table.insert(query_params, 'page=' .. opts.page)
  end

  if opts.project_id then
    table.insert(query_params, 'project_id=' .. opts.project_id)
  end

  if opts.filter_id then
    table.insert(query_params, 'filter_id=' .. opts.filter_id)
  end

  local query_string = table.concat(query_params, '&')
  local endpoint = 'issues'
  if query_string ~= '' then
    endpoint = endpoint .. '?' .. query_string
  end

  return self:call_api(endpoint, 'GET', nil, callback)
end

function M:create_issue(data, callback)
  return self:call_api('issues', 'POST', data, callback)
end

function M:update_issue(id, data, callback)
  return self:call_api('issues/' .. id, 'PATCH', data, callback)
end

function M:delete_issue(id, callback)
  return self:call_api('issues/' .. id, 'DELETE', nil, callback)
end

function M:get_issue_files(issue_id, callback)
  return self:call_api('issues/' .. issue_id .. '/files', 'GET', nil, callback)
end

function M:get_issue_file(issue_id, file_id, callback)
  return self:call_api('issues/' .. issue_id .. '/files/' .. file_id, 'GET', nil, callback)
end

function M:get_project_issues(project_id, callback)
  return self:get_issues({ project_id = project_id }, nil, callback)
end

function M:get_project_users(project_id, callback)
  return self:call_api('projects/' .. project_id .. '/users', 'GET', nil, callback)
end

function M:get_project_categories(project_id, callback)
  if callback then
    self:call_api('projects/' .. project_id, 'GET', nil, function(ok, project)
      if ok and project and project.projects and project.projects[1] then
        callback(true, project.projects[1].categories)
      else
        callback(false, {})
      end
    end)
    return
  end

  local ok, project = self:call_api('projects/' .. project_id, 'GET')
  if ok and project and project.projects and project.projects[1] then
    return true, project.projects[1].categories
  end
  return false, {}
end

function M:get_filtered_issues(filter_id, callback)
  return self:get_issues({ filter_id = filter_id }, nil, callback)
end

function M:get_all_issues(callback)
  return self:get_issues(nil, nil, callback)
end

function M:get_all_projects(callback)
  return self:call_api('projects', 'GET', nil, callback)
end

function M:get_assigned_issues(page_size, page, callback)
  return self:get_issues({ filter_id = 'assigned', page_size = page_size, page = page }, nil, callback)
end

function M:get_reported_issues(page_size, page, callback)
  return self:get_issues({ filter_id = 'reported', page_size = page_size, page = page }, nil, callback)
end

function M:get_monitored_issues(page_size, page, callback)
  return self:get_issues({ filter_id = 'monitored', page_size = page_size, page = page }, nil, callback)
end

function M:get_unassigned_issues(page_size, page, callback)
  return self:get_issues({ filter_id = 'unassigned', page_size = page_size, page = page }, nil, callback)
end

function M:add_attachments_to_issue(issue_id, data, callback)
  return self:call_api('issues/' .. issue_id .. '/files', 'POST', data, callback)
end

function M:create_issue_note(issue_id, data, callback)
  return self:call_api('issues/' .. issue_id .. '/notes', 'POST', data, callback)
end

function M:edit_issue_note(issue_id, note_id, data, callback)
  return self:call_api('issues/' .. issue_id .. '/notes/' .. note_id, 'PUT', data, callback)
end

function M:delete_issue_note(issue_id, note_id, callback)
  return self:call_api('issues/' .. issue_id .. '/notes/' .. note_id, 'DELETE', nil, callback)
end

function M:monitor_issue(issue_id, callback)
  return self:call_api('issues/' .. issue_id .. '/monitors', 'POST', nil, callback)
end

function M:unmonitor_issue(issue_id, user_id, callback)
  return self:call_api('issues/' .. issue_id .. '/monitors/' .. user_id, 'DELETE', nil, callback)
end

function M:add_tags_to_issue(issue_id, data, callback)
  return self:call_api('issues/' .. issue_id .. '/tags', 'POST', data, callback)
end

function M:remove_tags_from_issue(issue_id, tag_id, callback)
  return self:call_api('issues/' .. issue_id .. '/tags/' .. tag_id, 'DELETE', nil, callback)
end

function M:add_issue_relationship(issue_id, data, callback)
  return self:call_api('issues/' .. issue_id .. '/relationships/', 'POST', data, callback)
end

return M
