local M = {}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local config = require("mantis.config")

local function get_help_groups()
  local keymap = config.options.view_issues.keymap

  local groups = {
    {
      title = "Navigation",
      items = {
        { key = "next_page",  label = "Next page" },
        { key = "prev_page",  label = "Prev page" },
        { key = "open_issue", label = "Open issue" },
      },
    },
    {
      title = "Issues",
      items = {
        { key = "filter",          label = "Filter" },
        { key = "add_note",        label = "Add note" },
        { key = "create_issue",    label = "Create issue" },
        { key = "delete_issue",    label = "Delete issue" },
        { key = "assign_issue",    label = "Assign issue" },
        { key = "change_summary",  label = "Change summary" },
        { key = "change_status",   label = "Change status" },
        { key = "change_severity", label = "Change severity" },
        { key = "change_priority", label = "Change priority" },
        { key = "change_category", label = "Change category" },
      },
    },
    {
      title = "Selection",
      items = {
        { key = "toggle_select",   label = "Toggle select" },
        { key = "select_all",      label = "Select all" },
        { key = "clear_selection", label = "Clear selection" },
      },
    },
    {
      title = "Batch Operations",
      items = {
        { key = "batch_status",   label = "Batch status" },
        { key = "batch_priority", label = "Batch priority" },
        { key = "batch_severity", label = "Batch severity" },
        { key = "batch_category", label = "Batch category" },
        { key = "batch_assign",   label = "Batch assign" },
        { key = "batch_delete",   label = "Batch delete" },
      },
    },
    {
      title = "General",
      items = {
        { key = "toggle_group", label = "Toggle grouping" },
        { key = "refresh",      label = "Refresh" },
        { key = "help",         label = "Close help" },
        { key = "quit",         label = "Quit" },
      },
    },
  }

  -- Resolve key mappings
  for _, group in ipairs(groups) do
    local resolved = {}
    for _, item in ipairs(group.items) do
      local key = keymap[item.key]
      if key then
        table.insert(resolved, {
          key = key,
          label = item.label,
        })
      end
    end
    group.items = resolved
  end

  return groups
end

local function render_vertical(groups)
  local lines = {}
  local highlights = {}

  for i, group in ipairs(groups) do
    if i > 1 then
      table.insert(lines, "")
    end

    -- Section title
    local title_line = #lines + 1
    table.insert(lines, " " .. group.title)
    table.insert(highlights, { line = title_line, col = 0, end_col = #lines[title_line], hl = "Title" })

    -- Separator
    table.insert(lines, " " .. string.rep("-", #group.title))

    -- Calculate column widths for this group
    local key_width = 0
    for _, item in ipairs(group.items) do
      key_width = math.max(key_width, #item.key)
    end

    -- Items
    for _, item in ipairs(group.items) do
      local line = string.format("   %-" .. key_width .. "s  %s", item.key, item.label)
      local line_num = #lines + 1
      table.insert(lines, line)
      -- Highlight the key
      table.insert(highlights, { line = line_num, col = 3, end_col = 3 + key_width, hl = "Special" })
    end
  end

  return lines, highlights
end

local function render_horizontal(groups, max_cols)
  local lines = {}
  local highlights = {}
  local COLUMN_GAP = 3

  -- Split groups into rows based on max_cols
  local rows_of_groups = {}
  for i = 1, #groups, max_cols do
    local row = {}
    for j = i, math.min(i + max_cols - 1, #groups) do
      table.insert(row, groups[j])
    end
    table.insert(rows_of_groups, row)
  end

  for row_idx, row_groups in ipairs(rows_of_groups) do
    if row_idx > 1 then
      table.insert(lines, "")
    end

    -- Calculate widths for each group in this row
    for _, group in ipairs(row_groups) do
      local key_w = #group.title
      local label_w = 0
      for _, item in ipairs(group.items) do
        key_w = math.max(key_w, #item.key)
        label_w = math.max(label_w, #item.label)
      end
      group.key_width = key_w
      group.label_width = label_w
      group.col_width = key_w + 1 + label_w
    end

    -- Max rows in this section
    local max_rows = 0
    for _, group in ipairs(row_groups) do
      max_rows = math.max(max_rows, #group.items)
    end

    -- Header line
    local header_parts = {}
    local header_hl_positions = {}
    local pos = 1
    for _, group in ipairs(row_groups) do
      local title = string.format("%-" .. group.col_width .. "s", group.title)
      table.insert(header_parts, title)
      table.insert(header_hl_positions, { start = pos, finish = pos + #group.title })
      pos = pos + group.col_width + COLUMN_GAP
    end
    local header_line = " " .. table.concat(header_parts, string.rep(" ", COLUMN_GAP))
    local line_num = #lines + 1
    table.insert(lines, header_line)
    for _, hl_pos in ipairs(header_hl_positions) do
      table.insert(highlights, { line = line_num, col = hl_pos.start, end_col = hl_pos.finish, hl = "Title" })
    end

    -- Separator line
    local sep_parts = {}
    for _, group in ipairs(row_groups) do
      table.insert(sep_parts, string.rep("-", group.col_width))
    end
    table.insert(lines, " " .. table.concat(sep_parts, string.rep(" ", COLUMN_GAP)))

    -- Data rows
    for row = 1, max_rows do
      local cols = {}
      local key_hl_positions = {}
      pos = 1
      for _, group in ipairs(row_groups) do
        local item = group.items[row]
        if item then
          local cell = string.format("%-" .. group.key_width .. "s %-" .. group.label_width .. "s", item.key, item.label)
          table.insert(cols, cell)
          table.insert(key_hl_positions, { start = pos, finish = pos + group.key_width })
        else
          table.insert(cols, string.rep(" ", group.col_width))
        end
        pos = pos + group.col_width + COLUMN_GAP
      end
      local data_line = " " .. table.concat(cols, string.rep(" ", COLUMN_GAP))
      line_num = #lines + 1
      table.insert(lines, data_line)
      for _, hl_pos in ipairs(key_hl_positions) do
        table.insert(highlights, { line = line_num, col = hl_pos.start, end_col = hl_pos.finish, hl = "Special" })
      end
    end
  end

  return lines, highlights
end

function M.render()
  local groups = get_help_groups()
  local keymap = config.options.view_issues.keymap

  -- Calculate total width needed for all columns
  local COLUMN_GAP = 3
  local total_horizontal_width = 0
  for _, group in ipairs(groups) do
    local key_w = #group.title
    local label_w = 0
    for _, item in ipairs(group.items) do
      key_w = math.max(key_w, #item.key)
      label_w = math.max(label_w, #item.label)
    end
    total_horizontal_width = total_horizontal_width + key_w + 1 + label_w + COLUMN_GAP
  end
  total_horizontal_width = total_horizontal_width + 4 -- padding

  -- Decide layout based on screen width
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local lines, highlights
  local popup_width, popup_height

  if screen_width >= total_horizontal_width then
    -- Full horizontal layout (5 columns)
    lines, highlights = render_horizontal(groups, 5)
    popup_width = math.min(total_horizontal_width, screen_width - 4)
    popup_height = #lines + 2
  elseif screen_width >= math.floor(total_horizontal_width * 0.6) then
    -- 3 columns layout
    lines, highlights = render_horizontal(groups, 3)
    popup_width = math.min(math.floor(screen_width * 0.9), screen_width - 4)
    popup_height = #lines + 2
  elseif screen_width >= 50 then
    -- 2 columns layout
    lines, highlights = render_horizontal(groups, 2)
    popup_width = math.min(math.floor(screen_width * 0.9), screen_width - 4)
    popup_height = #lines + 2
  else
    -- Vertical layout for very narrow screens
    lines, highlights = render_vertical(groups)
    popup_width = math.min(40, screen_width - 4)
    popup_height = math.min(#lines + 2, screen_height - 4)
  end

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Keyboard Shortcuts ",
        top_align = "center",
        bottom = " " .. keymap.help .. " or q: close ",
        bottom_align = "center",
      },
    },
    position = "50%",
    size = {
      width = popup_width,
      height = popup_height,
    },
    zindex = 300,
  })

  popup:mount()

  -- Set buffer content then make readonly
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(popup.bufnr, "buftype", "nofile")

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("mantis_help")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(popup.bufnr, ns, hl.hl, hl.line - 1, hl.col, hl.end_col)
  end

  -- Keymaps to close
  local function close()
    popup:unmount()
  end

  popup:map("n", "q", close, { noremap = true, silent = true })
  popup:map("n", keymap.help, close, { noremap = true, silent = true })
  popup:map("n", "<Esc>", close, { noremap = true, silent = true })

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
end

return M
