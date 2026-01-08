local M = {}

local host_config = nil
local config = require('mantis.config')
local curl = require('plenary.curl')

function M.new(host_name)
  host_config = config.options.hosts[host_name]
  if not host_config then
    vim.notify('Mantis: Host "' .. (host_name or 'default') .. '" not configured.', vim.log.levels.ERROR)
    return nil
  end

  local instance = {
    url = host_config.url,
    token = host_config.token or os.getenv('MANTIS_API_TOKEN'),
  }

  if not instance.url or not instance.token then
    vim.notify('Mantis: URL or token not configured for host "' .. (host_name or 'default') .. '".', vim.log.levels.ERROR)
    return nil
  end

  return setmetatable(instance, { __index = M })
end

local function call_api(endpoint, method, data)
  if host_config == nil then
    return
  end

  method = method or 'GET'
  local headers = {
    ['Authorization'] = host_config.token,
    ['Content-Type'] = 'application/json',
  }

  local url = host_config.url .. '/api/rest/' .. endpoint

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
        local decoded_body, _ = pcall(vim.fn.json_decode, response.body)
        if decoded_body and decoded_body.message then
          error_message = decoded_body.message
        else
          error_message = response.body
        end
    end
    if config.options.debug then
      vim.notify('Mantis API Error: ' .. error_message, vim.log.levels.ERROR)
    end
    return nil
  end

  if response.body and response.body ~= '' then
    return vim.fn.json_decode(response.body)
  end

  return nil
end

--- Issues
function M:get_issue(id)
  return call_api('issues/' .. id)
end

function M:get_issues(page_size, page)
  page_size = page_size or 10
  page = page or 1
  return call_api('issues?page_size=' .. page_size .. '&page=' .. page)
end

function M:create_issue(data)
  return call_api('issues', 'POST', data)
end

function M:update_issue(id, data)
  return call_api('issues/' .. id, 'PATCH', data)
end

function M:delete_issue(id)
  return call_api('issues/' .. id, 'DELETE')
end

function M:get_issue_files(issue_id)
  return call_api('issues/' .. issue_id .. '/files', 'GET')
end

function M:get_issue_file(issue_id, file_id)
  return call_api('issues/' .. issue_id .. '/files/' .. file_id, 'GET')
end

function M:get_project_issues(project_id)
  return call_api('issues?project_id=' .. project_id, 'GET')
end

function M:get_project_users(project_id)
  return call_api('projects/' .. project_id .. '/users', 'GET')
end

function M:get_filtered_issues(filter_id)
  return call_api('issues?filter_id=' .. filter_id, 'GET')
end

function M:get_all_issues()
  return call_api('issues', 'GET')
end

function M:get_my_assigned_issues(page_size, page)
  page_size = page_size or 10
  page = page or 1
  return call_api('issues?filter_id=assigned&page_size=' .. page_size .. '&page=' .. page, 'GET')
end

function M:get_my_reported_issues()
  return call_api('issues?filter_id=reported', 'GET')
end

function M:get_my_monitored_issues()
  return call_api('issues?filter_id=monitored', 'GET')
end

function M:get_unassigned_issues()
  return call_api('issues?filter_id=unassigned', 'GET')
end

function M:add_attachments_to_issue(issue_id, data)
  return call_api('issues/' .. issue_id .. '/files', 'POST', data)
end

function M:create_issue_note(issue_id, data)
  return call_api('issues/' .. issue_id .. '/notes', 'POST', data)
end

function M:delete_issue_note(issue_id, note_id)
  return call_api('issues/' .. issue_id .. '/notes/' .. note_id, 'DELETE')
end

function M:monitor_issue(issue_id)
  return call_api('issues/' .. issue_id .. '/monitors', 'POST')
end

function M:add_tags_to_issue(issue_id, data)
  return call_api('issues/' .. issue_id .. '/tags', 'POST', data)
end

function M:remove_tags_from_issue(issue_id, data)
  return call_api('issues/' .. issue_id .. '/tags', 'POST', data)
end

function M:add_issue_relationship(issue_id, data)
  return call_api('issues/' .. issue_id .. '/relationships/', 'POST', data)
end

return M
