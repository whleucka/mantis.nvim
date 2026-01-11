vim.api.nvim_create_user_command('Mantis', function()
  -- Prompt to select host
  local _, ui = pcall(require, "mantis.ui")
  if not _ then
    print("Failed to load Mantis UI")
  end
  ui.host_select()
end, {
  desc = 'Open Mantis UI',
})
