vim.api.nvim_create_user_command('MantisIssues', function()
  require("mantis.ui").view_issues()
end, {
  desc = 'Open Mantis Issues',
})

vim.api.nvim_create_user_command('MantisSelectHost', function()
  require("mantis.ui").select_host()
end, {
  desc = 'Select Mantis Host',
})

vim.api.nvim_create_user_command('MantisIssue', function(opts)
  local issue_id = tonumber(opts.args)
  if not issue_id then
    vim.notify("Invalid issue ID: " .. opts.args, vim.log.levels.ERROR)
    return
  end
  local state = require("mantis.state")
  if not state.api then
    vim.notify("No host selected. Run :MantisSelectHost first.", vim.log.levels.WARN)
    return
  end
  require("mantis.ui").view_issue(issue_id)
end, {
  nargs = 1,
  desc = 'View Mantis Issue by ID',
})
