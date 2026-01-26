local M = {
  ---@type MantisAPI
  api = nil,
  page = 1,
  collapsed_projects = {},
  current_filter = nil, -- persists filter across view_issues sessions
}

return M
