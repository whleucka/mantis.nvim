-- Mantis.nvim UI
local M = {}

local mantis = require('mantis')
local config = require('mantis.config')
local util = require('mantis.util')

M.issues = {}

local function parse_iso_date(iso_date)
  if not iso_date then return '' end
  local year, month, day, hour, min, sec = iso_date:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if year then
    -- Assuming UTC, which may not be correct for all users.
    local t = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) })
    return os.date('%Y-%m-%d %H:%M', t)
  end
  return iso_date
end


local function open_float_win(content_height)
  local width = vim.api.nvim_get_option('columns')
  local height = vim.api.nvim_get_option('lines')

  local win_width = math.floor(width * 0.9)

  -- Dynamic height calculation
  local max_height = math.floor(height * 0.8)
  local win_height = math.min(content_height, max_height)

  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'single',
  })
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  return buf, win
end

local function display_message(message, is_error)
  local buf, win = open_float_win(3) -- 3 lines for the message
  local win_width = vim.api.nvim_win_get_width(win)
  local centered_message = string.rep(' ', math.floor((win_width - #message) / 2)) .. message
  local lines = {
    '', -- Empty line for padding
    centered_message,
    '', -- Empty line for padding
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(win, { 2, 0 }) -- Set cursor to the message line

  -- Define highlight for message
  vim.api.nvim_set_hl(0, 'MantisMessage', { italic = true, fg = is_error and '#FF0000' or '#888888', ctermfg = is_error and util.hex_to_cterm('#FF0000') or util.hex_to_cterm('#888888') })
  vim.api.nvim_buf_add_highlight(buf, -1, 'MantisMessage', 1, 0, -1)

  -- Key mappings (only q to close)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

M.current_host = nil

function M.show_assigned_issues(host_name)
  M.current_host = host_name -- Store the current host

  local client = mantis.new(host_name)
  if not client then
    display_message("An error occurred. Check mantis config.", true)
    return
  end

  local issues_data = client:get_my_assigned_issues()
  if not issues_data or not issues_data.issues or #issues_data.issues == 0 then
    display_message("No issues assigned to you.", false)
    return
  end

  M.issues = issues_data.issues
  -- Calculate required height
  -- title, empty, header, border, separator, empty, keymap_help, top/bottom border
  local content_lines = 8 + #M.issues
  local buf, win = open_float_win(content_lines)

  local win_width = vim.api.nvim_win_get_width(win)

  -- Define fixed column widths (without padding)
  local id_width = 11
  local status_width = 18 -- Increased to accommodate the box
  local project_width = 21
  local category_width = 21
  local updated_width = 20

  -- Calculate padding spaces (5 columns, 4 * 2 spaces)
  local padding_width = 8

  -- Calculate width of fixed columns
  local fixed_content_width = id_width + status_width + project_width + category_width + updated_width

  -- Calculate summary width
  local summary_width = win_width - fixed_content_width - padding_width

  if summary_width < 10 then summary_width = 10 end -- minimum width

  -- Create format string with padding
  local format_specifiers = {
    string.format('%%%ds', id_width),
    string.format('%%-%ds', status_width),
    string.format('%%-%ds', project_width),
    string.format('%%-%ds', category_width),
    string.format('%%-%ds', summary_width),
    string.format('%%-%ds', updated_width),
  }
  local format_string = table.concat(format_specifiers, '  ')

  local lines = {}
  local title = 'Mantis Issues [' .. host_name .. ']'
  local padding = math.floor((win_width - #title) / 2)
  table.insert(lines, string.rep(' ', padding) .. title)
  table.insert(lines, '') -- Empty line
  table.insert(lines, string.format(format_string, 'ID', 'Status', 'Project', 'Category', 'Summary', 'Updated'))
  table.insert(lines, string.rep('─', win_width))
  for idx, issue in ipairs(M.issues) do
    local id = tostring(issue.id)
    local status = issue.status.name
    local project = issue.project.name
    local category = issue.category.name
    local summary = issue.summary
    local updated = parse_iso_date(issue.updated_at)
    table.insert(lines, string.format(format_string, id, status, project, category, summary, updated))
  end

  -- Separator below issues
  table.insert(lines, string.rep('─', win_width))

  -- Empty line
  table.insert(lines, '')

  -- Keymap help area
  local keymap_help_text = "r: Refresh View | q: Quit"
  local keymap_padding = math.floor((win_width - #keymap_help_text) / 2)
  table.insert(lines, string.rep(' ', keymap_padding) .. keymap_help_text)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(win, { 5, 0 }) -- Cursor starts at 5th line (first issue)

  -- Define highlight for keymap help
  vim.api.nvim_set_hl(0, 'MantisKeymapHelp', { fg = '#888888', ctermfg = util.hex_to_cterm('#888888') })
  -- Apply highlight to keymap help line
  vim.api.nvim_buf_add_highlight(buf, -1, 'MantisKeymapHelp', #lines - 1, 0, -1)


  local defined_highlights = {}

  for i, issue in ipairs(M.issues) do
    if issue.status and issue.status.color then
      local color = issue.status.color
      local group_name = 'MantisStatus_' .. color:sub(2)

      if not defined_highlights[group_name] then
        local cterm_color = util.hex_to_cterm(color)

        local r, g, b = util.hex_to_rgb(color)
        local luminance = util.get_luminance(r, g, b)
        local fg_color = (luminance > 0.179) and '#000000' or '#FFFFFF' -- 0.179 is WCAG 2.0 contrast ratio for 3:1 (AA for large text)
        local cterm_fg_color = (luminance > 0.179) and util.hex_to_cterm('#000000') or util.hex_to_cterm('#FFFFFF')

        vim.api.nvim_set_hl(0, group_name, { bg = color, ctermbg = cterm_color, fg = fg_color, ctermfg = cterm_fg_color })
        defined_highlights[group_name] = true
      end

      -- Highlight the status text
      -- Line number is i + 3
      -- Status column starts after ID (id_width = 11) and 2 spaces padding, so at column 13
      -- Status width is status_width (18)
      local status_col_start = id_width + 2
      local status_col_end = status_col_start + status_width
      vim.api.nvim_buf_add_highlight(buf, -1, group_name, i + 3, status_col_start, status_col_end)
    end
  end

  -- Key mappings
  vim.api.nvim_buf_set_keymap(buf, 'n', 'j', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] < #M.issues + 4 then -- check if cursor is before last issue
        vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })
      end
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'k', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] > 5 then -- check if cursor is after first issue (line 5)
        vim.api.nvim_win_set_cursor(0, { cursor[1] - 1, cursor[2] })
      end
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'r', '', {
    noremap = true,
    silent = true,
    callback = function()
      M.show_assigned_issues(M.current_host)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

function M.select_host()
  local hosts = config.get_hosts()
  local host_names = {}
  for name, _ in pairs(hosts) do
    table.insert(host_names, name)
  end

  if #host_names == 0 then
    vim.notify('No hosts configured.', vim.log.levels.ERROR)
    return
  elseif #host_names == 1 then
    -- If there's only one host, just use it directly
    M.show_assigned_issues(host_names[1])
    return
  end

  vim.ui.select(host_names, { prompt = 'Select a Mantis Host:' }, function(choice)
    if choice then
      M.show_assigned_issues(choice)
    end
  end)
end

return M
