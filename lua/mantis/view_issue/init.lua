local M = {}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local config = require("mantis.config")
local options = config.options.view_issue
local state = require("mantis.state")
local helper = require("mantis.view_issue.helper")
local add_note = require("mantis.add_note")

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

  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

  for _, hl_data in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, hl_data.hl, hl_data.line - 1, 0, -1)
  end
end

local function fetch_issue(issue_id)
  local ok, res = state.api:get_issue(issue_id)
  if ok and res and res.issues and res.issues[1] then
    return res.issues[1]
  end
  return nil
end

function M.render(issue_id)
  local popup_width = options.ui.width
  local popup_height = options.ui.height

  local issue = fetch_issue(issue_id)

  if not issue then
    vim.notify("Failed to fetch issue #" .. issue_id, vim.log.levels.ERROR)
    return
  end

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Issue #" .. issue_id .. " ",
        top_align = "left",
        bottom = " q: quit | r: refresh | N: add note ",
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
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  render_content(popup, issue, popup_width)

  local function set_keymaps()
    local keymap = options.keymap

    popup:map("n", keymap.quit, function()
      popup:unmount()
    end, { noremap = true, silent = true })

    popup:map("n", keymap.refresh, function()
      local refreshed_issue = fetch_issue(issue_id)
      if refreshed_issue then
        issue = refreshed_issue
        render_content(popup, issue, popup_width)
        vim.notify("Issue #" .. issue_id .. " refreshed", vim.log.levels.INFO)
      else
        vim.notify("Failed to refresh issue #" .. issue_id, vim.log.levels.ERROR)
      end
    end, { noremap = true, silent = true })

    popup:map("n", keymap.add_note, function()
      add_note.render(issue_id, function()
        local refreshed_issue = fetch_issue(issue_id)
        if refreshed_issue then
          issue = refreshed_issue
          render_content(popup, issue, popup_width)
        end
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
  end

  set_keymaps()
end

return M
