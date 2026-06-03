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

  -- Issues the current user is monitoring (server-side state mirrored locally
  -- so the list view can show an indicator). Cleared on host switch.
  ---@type table<number, boolean> issue_id -> monitored
  monitored_issues = {},
}

--- Get project users with caching.
--- When `callback` is supplied the fetch is non-blocking and the result is
--- delivered via `callback(ok, users)`; otherwise it returns `ok, users`.
---@param project_id number
---@param callback? fun(ok: boolean, users: table[]) async result handler
---@param force_refresh? boolean
---@return boolean? ok
---@return table[]? users
function M.get_project_users(project_id, callback, force_refresh)
  if callback then
    if not force_refresh and M._users_cache[project_id] then
      callback(true, M._users_cache[project_id])
      return
    end
    M.api:get_project_users(project_id, function(ok, res)
      if ok and res and res.users then
        M._users_cache[project_id] = res.users
        callback(true, res.users)
      else
        callback(false, {})
      end
    end)
    return
  end

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

--- Get project categories with caching.
--- When `callback` is supplied the fetch is non-blocking and the result is
--- delivered via `callback(ok, categories)`; otherwise it returns `ok, categories`.
---@param project_id number
---@param callback? fun(ok: boolean, categories: table[]) async result handler
---@param force_refresh? boolean
---@return boolean? ok
---@return table[]? categories
function M.get_project_categories(project_id, callback, force_refresh)
  if callback then
    if not force_refresh and M._categories_cache[project_id] then
      callback(true, M._categories_cache[project_id])
      return
    end
    M.api:get_project_categories(project_id, function(ok, categories)
      if ok and categories then
        M._categories_cache[project_id] = categories
        callback(true, categories)
      else
        callback(false, {})
      end
    end)
    return
  end

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
  M.monitored_issues = {}
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

--- Check if the current user is monitoring an issue
---@param id number
---@return boolean
function M.is_monitored(id)
  return M.monitored_issues[id] == true
end

--- Set the monitored state for a single issue
---@param id number
---@param monitored boolean
function M.set_monitored(id, monitored)
  M.monitored_issues[id] = monitored and true or nil
end

--- Replace the whole monitored set from a list of issue IDs
---@param ids number[]
function M.set_monitored_ids(ids)
  local set = {}
  for _, id in ipairs(ids) do
    set[id] = true
  end
  M.monitored_issues = set
end

return M
