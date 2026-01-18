--                       __  .__                        .__         
--  _____ _____    _____/  |_|__| ______      _______  _|__| _____  
-- /     \\__  \  /    \   __\  |/  ___/     /    \  \/ /  |/     \ 
--|  Y Y  \/ __ \|   |  \  | |  |\___ \     |   |  \   /|  |  Y Y  \
--|__|_|  (____  /___|  /__| |__/____  > /\ |___|  /\_/ |__|__|_|  /
--      \/     \/     \/             \/  \/      \/              \/ 
--
-- MantisBT Neovim Client
-- Created by: William Hleucka 
-- Email: william.hleucka@gmail.com

local M = {}

local config = require('mantis.config')

function M.setup(opts)
  opts = opts or {}
  config.setup(opts)
  require("mantis.commands")
end

return M
