local M = {}

M.options = {
  hosts = {},
  verbose = false,
}

function M.setup(options)
  M.options = vim.tbl_deep_extend('force', M.options, options or {})
end

function M.get(host_name)
  if host_name then
    return M.options.hosts[host_name]
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

function M.get_hosts()
  return M.options.hosts
end

return M
