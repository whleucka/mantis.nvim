local M = {
  ---@type MantisAPI
  api = nil,
  page = 1,
  collapsed_projects = {},
  current_filter = nil, -- persists filter across view_issues sessions

  -- Per-project caches (cleared on host switch)
  ---@type table<number, table[]> project_id -> users array
  _users_cache = {},
  ---@type table<number, table[]> project_id -> categories array
  _categories_cache = {},
}

--- Get project users with caching
---@param project_id number
---@param force_refresh? boolean
---@return boolean ok
---@return table[] users
function M.get_project_users(project_id, force_refresh)
  if not force_refresh and M._users_cache[project_id] then
    return true, M._users_cache[project_id]
  end

  local ok, res = M.api:get_project_users(project_id)
  if ok and res and res.users then
    M._users_cache[project_id] = res.users
    return true, res.users
  end

  return false, {}
end

--- Get project categories with caching
---@param project_id number
---@param force_refresh? boolean
---@return boolean ok
---@return table[] categories
function M.get_project_categories(project_id, force_refresh)
  if not force_refresh and M._categories_cache[project_id] then
    return true, M._categories_cache[project_id]
  end

  local ok, categories = M.api:get_project_categories(project_id)
  if ok and categories then
    M._categories_cache[project_id] = categories
    return true, categories
  end

  return false, {}
end

--- Clear all caches (call when switching hosts)
function M.clear_caches()
  M._users_cache = {}
  M._categories_cache = {}
end

return M
