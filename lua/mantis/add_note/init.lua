local M = {}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local config = require("mantis.config")
local options = config.options.add_note
local state = require("mantis.state")
local helper = require("mantis.add_note.helper")

function M.render(issue_id, refresh_view)
  local popup_width = options.ui.width
  local popup_height = options.ui.height

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "Add Note to Issue #" .. issue_id,
        top_align = "left",
        bottom = " " .. options.keymap.quit .. ": quit | " .. options.keymap.submit .. ": submit ",
        bottom_align = "right",
      },
    },
    position = "50%",
    size = {
      width = popup_width,
      height = popup_height,
    },
    zindex = 250,
    win_options = { wrap = true },
  })

  -- mount/unmount logic
  popup:mount()
  vim.cmd("startinsert")
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  -- keymaps
  local function set_keymaps()
    local keymap = options.keymap

    popup:map("n", keymap.quit, function()
      popup:unmount()
    end, { noremap = true, silent = true })

    popup:map("n", keymap.submit, function()
      local note_text = table.concat(vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false), "\n")

      if note_text == "" then
        vim.notify("Note text cannot be empty.", vim.log.levels.WARN)
        return
      end

      vim.ui.input({ prompt = "Track time? (HH:MM) (y/n) ", default = "n" }, function(input)
        if not input or input:lower() == "n" then
          local data = {
            text = note_text,
          }
          local ok, _ = state.api:create_issue_note(issue_id, data)
          if ok then
            vim.notify("Note added successfully.")
            refresh_view()
            popup:unmount()
          else
            vim.notify("Failed to add note.", vim.log.levels.ERROR)
          end
          return
        end

        if input:lower() == "y" then
          vim.ui.input({ prompt = "Enter time (HH:MM) " }, function(time_input)
            if not time_input then
              return
            end
            local is_valid, duration = helper.validate_time(time_input)
            if not is_valid then
              vim.notify("Invalid time format.", vim.log.levels.ERROR)
              return
            end
            local data = {
              text = note_text,
              time_tracking = {
                duration = duration,
              },
            }
            local ok, _ = state.api:create_issue_note(issue_id, data)
            if ok then
              vim.notify("Note added successfully with time tracking.")
              refresh_view()
              popup:unmount()
            else
              vim.notify("Failed to add note with time tracking.", vim.log.levels.ERROR)
            end
          end)
        else
          local is_valid, duration = helper.validate_time(input)
          if not is_valid then
            vim.notify("Invalid time format.", vim.log.levels.ERROR)
            return
          end
          local data = {
            text = note_text,
            time_tracking = {
              duration = duration,
            },
          }
          local ok, _ = state.api:create_issue_note(issue_id, data)
          if ok then
            vim.notify("Note added successfully with time tracking.")
            refresh_view()
            popup:unmount()
          else
            vim.notify("Failed to add note with time tracking.", vim.log.levels.ERROR)
          end
        end
      end)
    end, { noremap = true, silent = true })
  end

  set_keymaps()
end

return M
