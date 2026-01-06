-- Mantis.nvim Configuration
local M = {}

M.options = {
  default_host = nil,
  hosts = {},
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

function M.get(host_name)
  if host_name then
    return M.options.hosts[host_name]
  end
  if M.options.default_host then
    return M.options.hosts[M.options.default_host]
  end
  -- Backwards compatibility
  if M.options.url then
    return {
      url = M.options.url,
      token = M.options.token
    }
  end
  return nil
end

return M