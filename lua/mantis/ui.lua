local M = {}

local state = require('mantis.state')

-- show MantisBT table
function M.view_issues()
  local ok, mod =  pcall(require, "mantis.view_issues")
  if not ok then
    vim.notify("Failed to load mantis.view_issues", vim.log.levels.ERROR)
    return
  end
  mod.render()
end

-- select a host from config
function M.select_host()
  local ok, mod =  pcall(require, "mantis.select_host")
  if not ok then
    vim.notify("Failed to load mantis.select_host", vim.log.levels.ERROR)
    return
  end
  mod.render()
end

-- add issue note
function M.add_note(issue_id)
  local ok, mod_or_err = pcall(require, "mantis.add_note")
  if not ok then
    vim.notify("Failed to load mantis.add_note: " .. mod_or_err, vim.log.levels.ERROR)
    return
  end
  mod_or_err.render(issue_id)
end

-- check if api is read
if not state.api then
  M.select_host()
end

return M
