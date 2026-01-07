local M = {}

function M.setup(opts)
  local config = require('mantis.config')
  opts = opts or {}
  config.setup(opts)
  require("mantis.commands")
end

return M
