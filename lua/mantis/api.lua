---@class MantisAPI
---@field get_issue fun(self, id: number): table
---@field get_issues fun(self, opts_or_page_size?: table|number, page?: number): table
---@field create_issue fun(self, data: table): table
---@field update_issue fun(self, id: number, data: table): table
---@field delete_issue fun(self, id: number): nil
---@field get_issue_files fun(self, issue_id: number): table
---@field get_issue_file fun(self, issue_id: number, file_id: number): table
---@field get_project_issues fun(self, project_id: number): table
---@field get_project_users fun(self, project_id: number): table
---@field get_filtered_issues fun(self, filter_id: string|number): table
---@field get_all_issues fun(self): table
---@field get_all_projects fun(self): table
---@field get_assigned_issues fun(self, page_size?: number, page?: number): table
---@field get_reported_issues fun(self, page_size?: number, page?: number): table
---@field get_monitored_issues fun(self, page_size?: number, page?: number): table
---@field get_unassigned_issues fun(self, page_size?: number, page?: number): table
---@field add_attachments_to_issue fun(self, issue_id: number, data: table): table
---@field create_issue_note fun(self, issue_id: number, data: table): table
---@field delete_issue_note fun(self, issue_id: number, note_id: number): nil
---@field monitor_issue fun(self, issue_id: number): table
---@field add_tags_to_issue fun(self, issue_id: number, data: table): table
---@field remove_tags_from_issue fun(self, issue_id: number, tag_id: number): nil
---@field add_issue_relationship fun(self, issue_id: number, data: table): table

local M = {}

local config = require('mantis.config')
local curl = require('plenary.curl')

---@return MantisAPI
function M.new(host_config)
  local instance = {}
  if not host_config then
    vim.notify('Mantis: Host "' .. (host_config.url or 'default') .. '" not configured.', vim.log.levels.ERROR)
    return nil
  end

  instance.name = host_config.url
  instance.url = host_config.url
  instance.token = host_config.token or os.getenv(host_config.env)

  if not instance.url or not instance.token then
    vim.notify('Mantis: URL or token not configured for host "' .. (host_config.url or 'default') .. '".', vim.log.levels
    .ERROR)
    return nil
  end

  return setmetatable(instance, { __index = M })
end

function M:call_api(endpoint, method, data)
  if self.url == nil then
    return
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

  local response
  if method == 'GET' then
    response = curl.get(url, opts)
  elseif method == 'POST' then
    response = curl.post(url, opts)
  elseif method == 'PATCH' then
    response = curl.patch(url, opts)
  elseif method == 'DELETE' then
    response = curl.delete(url, opts)
  else
    vim.notify('Mantis API Error: Unsupported method ' .. method, vim.log.levels.ERROR)
    return nil
  end

  if config.options.debug then
    print('Mantis API Response:')
    print('Status: ' .. response.status)
    print('Body: ' .. response.body)
  end

  if response.status ~= 200 and response.status ~= 201 and response.status ~= 204 then
    local error_message = "Mantis API Error"
    if response.body and response.body ~= "" then
      local ok, decoded = pcall(vim.fn.json_decode, response.body)

      if ok and type(decoded) == "table" and decoded.message then
        error_message = decoded.message
      else
        error_message = response.body
      end
    end
    vim.notify('Mantis API Error: ' .. error_message, vim.log.levels.ERROR) -- always notify
    return nil
  end

  if response.body and response.body ~= '' then
    return vim.fn.json_decode(response.body)
  end

  return nil
end

--- issues
function M:get_issue(id)
  return self:call_api('issues/' .. id)
end

function M:get_issues(opts_or_page_size, page)
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

  return self:call_api(endpoint)
end

function M:create_issue(data)
  return self:call_api('issues', 'POST', data)
end

function M:update_issue(id, data)
  return self:call_api('issues/' .. id, 'PATCH', data)
end

function M:delete_issue(id)
  return self:call_api('issues/' .. id, 'DELETE')
end

function M:get_issue_files(issue_id)
  return self:call_api('issues/' .. issue_id .. '/files', 'GET')
end

function M:get_issue_file(issue_id, file_id)
  return self:call_api('issues/' .. issue_id .. '/files/' .. file_id, 'GET')
end

function M:get_project_issues(project_id)
  return self:get_issues({ project_id = project_id })
end

function M:get_project_users(project_id)
  return self:call_api('projects/' .. project_id .. '/users', 'GET')
end

function M:get_filtered_issues(filter_id)
  return self:get_issues({ filter_id = filter_id })
end

function M:get_all_issues()
  return self:get_issues()
end

function M:get_all_projects()
  return self:call_api('projects', 'GET')
end

function M:get_assigned_issues(page_size, page)
  return self:get_issues({ filter_id = 'assigned', page_size = page_size, page = page })
end

function M:get_reported_issues(page_size, page)
  return self:get_issues({ filter_id = 'reported', page_size = page_size, page = page })
end

function M:get_monitored_issues(page_size, page)
  return self:get_issues({ filter_id = 'monitored', page_size = page_size, page = page })
end

function M:get_unassigned_issues(page_size, page)
  return self:get_issues({ filter_id = 'unassigned', page_size = page_size, page = page })
end

function M:add_attachments_to_issue(issue_id, data)
  return self:call_api('issues/' .. issue_id .. '/files', 'POST', data)
end

function M:create_issue_note(issue_id, data)
  return self:call_api('issues/' .. issue_id .. '/notes', 'POST', data)
end

function M:delete_issue_note(issue_id, note_id)
  return self:call_api('issues/' .. issue_id .. '/notes/' .. note_id, 'DELETE')
end

function M:monitor_issue(issue_id)
  return self:call_api('issues/' .. issue_id .. '/monitors', 'POST')
end

function M:add_tags_to_issue(issue_id, data)
  return self:call_api('issues/' .. issue_id .. '/tags', 'POST', data)
end

function M:remove_tags_from_issue(issue_id, tag_id)
  return self:call_api('issues/' .. issue_id .. '/tags/' .. tag_id, 'DELETE')
end

function M:add_issue_relationship(issue_id, data)
  return self:call_api('issues/' .. issue_id .. '/relationships/', 'POST', data)
end

return M
