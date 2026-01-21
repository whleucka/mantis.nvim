local M = {}

local state = require('mantis.state')

-- show MantisBT issues
function M.view_issues()
  local ok, mod =  pcall(require, "mantis.view_issues")
  if not ok then
    vim.notify("Failed to load mantis.view_issues: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render()
end

-- select a host from config
function M.select_host()
  local ok, mod =  pcall(require, "mantis.select_host")
  if not ok then
    vim.notify("Failed to load mantis.select_host: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render()
end

-- add issue note
function M.add_note(issue_id, cb)
  local ok, mod = pcall(require, "mantis.add_note")
  if not ok then
    vim.notify("Failed to load mantis.add_note: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render(issue_id, cb)
end

-- view issue
function M.view_issue(issue_id)
  local ok, mod = pcall(require, "mantis.view_issue")
  if not ok then
    vim.notify("Failed to load mantis.view_issue: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render(issue_id)
end

-- create issue
function M.create_issue(project_id)
  local ok, mod = pcall(require, "mantis.create_issue")
  if not ok then
    vim.notify("Failed to load mantis.create_issue: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render(project_id)
end

-- check if api is read
if not state.api then
  M.select_host()
end

return M
