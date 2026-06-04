local M = {}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local config = require("mantis.config")
local state = require("mantis.state")
local helper = require("mantis.view_issue.helper")
local add_note = require("mantis.add_note")
local util = require("mantis.util")

local ns = vim.api.nvim_create_namespace("mantis_issue")

local function render_content(popup, issue, width)
  local formatted = helper.format_issue(issue, width)

  local lines = {}
  local highlights = {}

  for i, line_data in ipairs(formatted) do
    table.insert(lines, line_data.text or "")
    if line_data.hl then
      table.insert(highlights, { line = i, hl = line_data.hl })
    end
  end

  vim.bo[popup.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  -- Clear prior highlights so a refresh/re-render does not stack extmarks.
  vim.api.nvim_buf_clear_namespace(popup.bufnr, ns, 0, -1)
  for _, hl_data in ipairs(highlights) do
    local row = hl_data.line - 1
    vim.api.nvim_buf_set_extmark(popup.bufnr, ns, row, 0, {
      end_row = row,
      end_col = #(lines[hl_data.line] or ""),
      hl_group = hl_data.hl,
      strict = false,
    })
  end
end

--- Fetch a single issue without blocking the editor.
---@param issue_id number
---@param callback fun(issue: table|nil)
local function fetch_issue(issue_id, callback)
  vim.notify("Loading issue #" .. issue_id .. "...", vim.log.levels.INFO)
  state.api:get_issue(issue_id, function(ok, res)
    if ok and res and res.issues and res.issues[1] then
      callback(res.issues[1])
    else
      callback(nil)
    end
  end)
end

function M.render(issue_id)
  local options = config.options.view_issue
  local popup_width = util.resolve_dimension(options.ui.width, vim.o.columns, options.ui.max_width)
  local popup_height = util.resolve_dimension(options.ui.height, vim.o.lines, options.ui.max_height)

  -- Remember the window we were launched from (the issues list) so focus can
  -- be returned there when the popup closes, instead of falling through to
  -- whatever window happens to sit behind it.
  local origin_win = vim.api.nvim_get_current_win()

  fetch_issue(issue_id, function(issue)
    if not issue then
      vim.notify("Failed to fetch issue #" .. issue_id, vim.log.levels.ERROR)
      return
    end

    local function restore_focus()
      vim.schedule(function()
        if origin_win and vim.api.nvim_win_is_valid(origin_win) then
          pcall(vim.api.nvim_set_current_win, origin_win)
        end
      end)
    end

    local popup = Popup({
      enter = true,
      focusable = true,
      border = {
        style = "rounded",
        text = {
          top = " Issue #" .. issue_id .. " ",
          top_align = "left",
          bottom = " " .. options.keymap.quit .. ": quit | " .. options.keymap.refresh .. ": refresh | " .. options.keymap.add_note .. ": add | " .. options.keymap.delete_note .. ": delete note ",
          bottom_align = "right",
        },
      },
      position = "50%",
      size = {
        width = popup_width,
        height = popup_height,
      },
      zindex = 200,
      win_options = {
        wrap = true,
        cursorline = false,
      },
      buf_options = {
        modifiable = false,
        filetype = "mantis-issue",
      },
    })

    popup:mount()
    popup:on(event.WinClosed, function()
      popup:unmount()
      restore_focus()
    end)

    render_content(popup, issue, popup_width)

    local keymap = options.keymap

    popup:map("n", keymap.quit, function()
      popup:unmount()
      restore_focus()
    end, { noremap = true, silent = true })

    popup:map("n", keymap.refresh, function()
      fetch_issue(issue_id, function(refreshed_issue)
        if refreshed_issue then
          issue = refreshed_issue
          render_content(popup, issue, popup_width)
          vim.notify("Issue #" .. issue_id .. " refreshed", vim.log.levels.INFO)
        else
          vim.notify("Failed to refresh issue #" .. issue_id, vim.log.levels.ERROR)
        end
      end)
    end, { noremap = true, silent = true })

    popup:map("n", keymap.add_note, function()
      add_note.render(issue_id, function()
        fetch_issue(issue_id, function(refreshed_issue)
          if refreshed_issue then
            issue = refreshed_issue
            render_content(popup, issue, popup_width)
          end
        end)
      end)
    end, { noremap = true, silent = true })

    popup:map("n", keymap.delete_note, function()
      if not issue.notes or #issue.notes == 0 then
        vim.notify("No notes to delete.", vim.log.levels.WARN)
        return
      end

      vim.ui.select(issue.notes, {
        prompt = "Select a note to delete",
        format_item = function(note)
          local reporter = note.reporter and (note.reporter.real_name or note.reporter.name) or "Unknown"
          local preview = (note.text or ""):gsub("\n", " ")
          if #preview > 60 then
            preview = preview:sub(1, 57) .. "..."
          end
          return string.format("[%s] %s", reporter, preview)
        end,
      }, function(note)
        if not note then
          return
        end

        vim.ui.input({
          prompt = "Delete this note? (y/n) ",
          default = "n",
        }, function(input)
          if not input or input:lower() ~= "y" then
            vim.notify("Deletion cancelled.", vim.log.levels.INFO)
            return
          end

          state.api:delete_issue_note(issue_id, note.id, function(ok)
            if ok then
              vim.notify("Note deleted.", vim.log.levels.INFO)
              fetch_issue(issue_id, function(refreshed_issue)
                if refreshed_issue then
                  issue = refreshed_issue
                  render_content(popup, issue, popup_width)
                end
              end)
            else
              vim.notify("Failed to delete note.", vim.log.levels.ERROR)
            end
          end)
        end)
      end)
    end, { noremap = true, silent = true })

    popup:map("n", keymap.scroll_down, function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      local line_count = vim.api.nvim_buf_line_count(popup.bufnr)
      if cursor[1] < line_count then
        vim.api.nvim_win_set_cursor(popup.winid, { cursor[1] + 1, cursor[2] })
      end
    end, { noremap = true, silent = true })

    popup:map("n", keymap.scroll_up, function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      if cursor[1] > 1 then
        vim.api.nvim_win_set_cursor(popup.winid, { cursor[1] - 1, cursor[2] })
      end
    end, { noremap = true, silent = true })

    popup:map("n", keymap.page_down, function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      local line_count = vim.api.nvim_buf_line_count(popup.bufnr)
      local new_line = math.min(cursor[1] + 10, line_count)
      vim.api.nvim_win_set_cursor(popup.winid, { new_line, cursor[2] })
    end, { noremap = true, silent = true })

    popup:map("n", keymap.page_up, function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      local new_line = math.max(cursor[1] - 10, 1)
      vim.api.nvim_win_set_cursor(popup.winid, { new_line, cursor[2] })
    end, { noremap = true, silent = true })

    popup:map("n", keymap.goto_bottom, function()
      local line_count = vim.api.nvim_buf_line_count(popup.bufnr)
      vim.api.nvim_win_set_cursor(popup.winid, { line_count, 0 })
    end, { noremap = true, silent = true })

    popup:map("n", keymap.goto_top, function()
      vim.api.nvim_win_set_cursor(popup.winid, { 1, 0 })
    end, { noremap = true, silent = true })
  end)
end

return M
