local M = {}

local state = require('mantis.state')

--- Ensure a host is selected before running an action.
--- If no host is configured, prompts the user to select one first.
---@param fn function The action to run after host is confirmed
local function ensure_host(fn)
  if state.api then
    fn()
    return
  end
  local ok, mod = pcall(require, "mantis.select_host")
  if not ok then
    vim.notify("Failed to load mantis.select_host: " .. mod, vim.log.levels.ERROR)
    return
  end
  mod.render(function()
    if state.api then
      fn()
    end
  end)
end

-- show MantisBT issues
function M.view_issues()
  ensure_host(function()
    local ok, mod = pcall(require, "mantis.view_issues")
    if not ok then
      vim.notify("Failed to load mantis.view_issues: " .. mod, vim.log.levels.ERROR)
      return
    end
    mod.render()
  end)
end

-- select a host from config
function M.select_host()
  local ok, mod = pcall(require, "mantis.select_host")
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
  ensure_host(function()
    local ok, mod = pcall(require, "mantis.view_issue")
    if not ok then
      vim.notify("Failed to load mantis.view_issue: " .. mod, vim.log.levels.ERROR)
      return
    end
    mod.render(issue_id)
  end)
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

return M
