local ui = require('mantis.ui')

vim.api.nvim_create_user_command('Mantis', function()
  -- Prompt to select host
  ui.host_select()
end, {
  desc = 'Open Mantis UI',
})
