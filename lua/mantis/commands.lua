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
