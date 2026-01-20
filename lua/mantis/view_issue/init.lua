local M = {}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local config = require("mantis.config")
local options = config.options.view_issue
local state = require("mantis.state")
local helper = require("mantis.view_issue.helper")

function M.render(issue_id)
  local popup_width = options.ui.width
  local popup_height = options.ui.height

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "Issue #" .. issue_id,
        top_align = "left",
      },
    },
    position = "50%",
    size = {
      width = popup_width,
      height = popup_height,
    },
    zindex = 200,
    win_options = { wrap = true },
  })

  -- mount/unmount logic
  popup:mount()
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  -- keymaps
  local function set_keymaps()
    local keymap = options.keymap

    popup:map("n", keymap.quit, function()
      popup:unmount()
    end, { noremap = true, silent = true })

  end
  set_keymaps()
end

return M
