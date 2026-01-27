local M = {
  ---@type MantisAPI
  api = nil,
  page = 1,
  collapsed_projects = {},
  current_filter = nil, -- persists filter across view_issues sessions
  grouped = true, -- persists grouped view across view_issues sessions

  -- Per-project caches (cleared on host switch)
  ---@type table<number, table[]> project_id -> users array
  _users_cache = {},
  ---@type table<number, table[]> project_id -> categories array
  _categories_cache = {},

  -- Selection state for batch operations
  ---@type table<number, boolean> issue_id -> selected
  selected_issues = {},
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

--- Toggle selection state for an issue
---@param id number
function M.toggle_selection(id)
  if M.selected_issues[id] then
    M.selected_issues[id] = nil
  else
    M.selected_issues[id] = true
  end
end

--- Check if an issue is selected
---@param id number
---@return boolean
function M.is_selected(id)
  return M.selected_issues[id] == true
end

--- Clear all selections
function M.clear_selection()
  M.selected_issues = {}
end

--- Get count of selected issues
---@return number
function M.selection_count()
  local count = 0
  for _ in pairs(M.selected_issues) do
    count = count + 1
  end
  return count
end

--- Get array of selected issue IDs
---@return number[]
function M.get_selected_ids()
  local ids = {}
  for id in pairs(M.selected_issues) do
    table.insert(ids, id)
  end
  return ids
end

return M
