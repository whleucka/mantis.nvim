local mantis_ns = vim.api.nvim_create_namespace('mantis')

local M = {}

local mantis = require('mantis')
local config = require('mantis.config')
local util = require('mantis.util')

M.issues = {}
M.active_view = "assigned"
M.current_buf = nil
M.current_win = nil

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
  local width = vim.o.columns
  local height = vim.o.lines

  local win_width = math.floor(width * 0.85) -- Assuming this is the desired width
  local max_height = math.floor(height * 0.8)
  local win_height = math.min(content_height, max_height)

  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)

  local buf, win

  if M.current_buf and vim.api.nvim_buf_is_valid(M.current_buf) and
     M.current_win and vim.api.nvim_win_is_valid(M.current_win) then
    -- Reuse existing window and buffer
    buf = M.current_buf
    win = M.current_win

    -- Clear buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    -- Resize and reposition the window
    vim.api.nvim_win_set_config(win, {
      relative = 'editor',
      width = win_width,
      height = win_height,
      row = row,
      col = col,
    })
  else
    -- Create new window and buffer
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
    })
    vim.wo[win].cursorline = true

    -- Store them for future reuse
    M.current_buf = buf
    M.current_win = win
  end

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
  local message_line_content = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
  local message_line_end_col = #message_line_content
  vim.api.nvim_buf_set_extmark(buf, mantis_ns, 1, 0, { end_col = message_line_end_col, hl_group = 'MantisMessage' })

  -- Define highlight for dimmer text
  vim.api.nvim_set_hl(0, 'MantisDimText', { fg = '#666666', ctermfg = util.hex_to_cterm('#666666') })

  -- Define highlight for active button
  vim.api.nvim_set_hl(0, 'MantisActiveButton', { bold = true, fg = '#FFFFFF', ctermfg = util.hex_to_cterm('#FFFFFF'), bg = '#5F87AF', ctermbg = util.hex_to_cterm('#5F87AF') })

  -- Key mappings (only q to close)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

M.current_host = nil

function M.show_assigned_issues(host_name, view_mode)
  view_mode = view_mode or "assigned"
  M.current_host = host_name -- Store the current host
  M.active_view = view_mode -- Set the active view for highlighting
  local extmarks_to_apply = {} -- Initialize extmarks_to_apply here

  local client = mantis.new(host_name)
  if not client then
    display_message("An error occurred. Check mantis config.", true)
    return
  end

  local issues_data
  if view_mode == "assigned" then
    issues_data = client:get_my_assigned_issues()
  elseif view_mode == "all" then
    -- Assuming get_all_issues exists in the client for now.
    -- If not, it will return nil and fallback to assigned.
    issues_data = client:get_all_issues()
  else
    -- Default fallback if view_mode is unexpected
    issues_data = client:get_my_assigned_issues()
  end

  if not issues_data or not issues_data.issues or #issues_data.issues == 0 then
    display_message("No issues found 🎉", false)
    return
  end

  M.issues = issues_data.issues
  -- Calculate required height
  -- title, empty, header, border, separator, empty, keymap_help, top/bottom border
  local content_lines = 8 + #M.issues
  local buf, win = open_float_win(content_lines)

  local win_width = vim.api.nvim_win_get_width(win)

  -- Define fixed column widths (without padding)
  local id_width = 8
  local priority_width = 10
  local severity_width = 8
  local status_width = 15
  local project_category_width = 30 -- Combined project and category
  local updated_width = 15

  -- Calculate padding spaces (6 columns, 6 * 2 spaces)
  local padding_width = 12

  -- Calculate width of fixed columns
  local fixed_content_width = id_width + priority_width + severity_width + status_width + project_category_width + updated_width

  -- Calculate summary width
  local summary_width = win_width - fixed_content_width - padding_width

  if summary_width < 10 then summary_width = 10 end -- minimum width

  -- Create format string with padding
  local format_specifiers = {
    string.format('%%%ds', id_width),
    string.format('%%-%ds', status_width),
    string.format('%%-%ds', priority_width),
    string.format('%%-%ds', severity_width),
    string.format('%%-%ds', project_category_width), -- Combined project and category
    string.format('%%-%ds', summary_width),
    string.format('%%%ds', updated_width),
  }
  local format_string = table.concat(format_specifiers, '  ')

  local lines = {}
  local title = '🪲 Mantis Issues [' .. host_name .. ']'
  local padding = math.floor((win_width - #title) / 2)
  table.insert(lines, string.rep(' ', padding) .. title) -- Line 0
  table.insert(lines, '') -- Line 1 (empty)
  table.insert(lines, string.format(format_string, 'ID', 'STATUS', 'PRIORITY', 'SEVERITY', 'CONTEXT', 'SUMMARY', 'LAST UPDATED')) -- Line 2 (header)
  table.insert(lines, string.rep('─', win_width)) -- Line 3 (separator below header)

  local defined_highlights = {} -- Moved here, outside the loop

  for idx, issue in ipairs(M.issues) do
    local id_str = string.format('%' .. id_width .. 's', tostring(issue.id))
    local priority_str = string.format('%%-%ds', priority_width):format(issue.priority and issue.priority.name or 'N/A')
    local severity_str = string.format('%%-%ds', severity_width):format(issue.severity and issue.severity.name or 'N/A')
    local status_display = issue.status.name
    if issue.handler and issue.handler.name then
      local handler_name = issue.handler.name
      local current_length = #status_display
      local required_space = #handler_name + 3 -- for " (" and ")"
      if current_length + required_space > status_width then
        -- Truncate handler_name if it causes overflow
        local available_space = status_width - current_length - 3
        if available_space > 0 then
          handler_name = handler_name:sub(1, available_space)
        else
          handler_name = "" -- No space for handler name
        end
      end
      if #handler_name > 0 then
        status_display = status_display .. ' (' .. handler_name .. ')'
      end
    end
    local status_str = string.format('%-' .. status_width .. 's', status_display)
    local project_category_display = string.format('%s [%s]', issue.project.name, issue.category.name)
    local project_category_str = string.format('%-' .. project_category_width .. 's', project_category_display)
    local summary_val = issue.summary
    if #summary_val > summary_width then
      summary_val = summary_val:sub(1, summary_width - 3) .. '...'
    end
    local summary_str = string.format('%-' .. summary_width .. 's', summary_val)

    local updated_val = parse_iso_date(issue.updated_at)
    local updated_str = string.format('%' .. updated_width .. 's', updated_val) -- Right-aligned

    local full_line = table.concat({
      id_str,
      status_str,
      priority_str,
      severity_str,
      project_category_str, -- Combined column
      summary_str,
      updated_str,
    }, '  ') -- Two spaces between columns

    table.insert(lines, full_line)

    -- Store extmark details for MantisDimText (UPDATED column)
    local updated_col_start = #id_str + 2 + -- id_str + 2 spaces
                              #status_str + 2 + -- status_str + 2 spaces
                              #priority_str + 2 + -- priority_str + 2 spaces
                              #severity_str + 2 + -- severity_str + 2 spaces
                              #project_category_str + 2 + -- combined column + 2 spaces
                              #summary_str + 2 -- summary_str + 2 spaces
    local updated_col_end = updated_col_start + #updated_str

    table.insert(extmarks_to_apply, {
      line = #lines - 1, -- 0-indexed line number
      col_start = updated_col_start,
      col_end = updated_col_end,
      hl_group = 'MantisDimText'
    })

    -- Store extmark details for MantisStatus_ highlights
    if issue.status and issue.status.color then
      local color = issue.status.color
      local group_name = 'MantisStatus_' .. color:sub(2)

      if not defined_highlights[group_name] then
        local cterm_color = util.hex_to_cterm(color)
        local r, g, b = util.hex_to_rgb(color)
        local luminance = util.get_luminance(r, g, b)
        local fg_color = (luminance > 0.179) and '#000000' or '#FFFFFF'
        local cterm_fg_color = (luminance > 0.179) and util.hex_to_cterm('#000000') or util.hex_to_cterm('#FFFFFF')
        vim.api.nvim_set_hl(0, group_name, { bg = color, ctermbg = cterm_color, fg = fg_color, ctermfg = cterm_fg_color })
        defined_highlights[group_name] = true
      end

      local status_col_start = id_width + 2
      local status_col_end = status_col_start + status_width
      table.insert(extmarks_to_apply, {
        line = #lines - 1, -- 0-indexed line number
        col_start = status_col_start,
        col_end = status_col_end,
        hl_group = group_name
      })
    end

    -- Store extmark details for priority highlights
    if issue.priority and issue.priority.name then
      local priority_name = issue.priority.name:lower()
      local color_map = {
        low = '#A8E6CF',      -- Pastel Green
        normal = '#AEC6CF',   -- Pastel Blue
        high = '#FDFD96',     -- Pastel Yellow
        urgent = '#FFB347',   -- Pastel Orange
        immediate = '#FF6961' -- Pastel Red
      }
      local color = color_map[priority_name]

      if color then
        local group_name = 'MantisPriority_' .. priority_name:gsub('%s+', '_')

        if not defined_highlights[group_name] then
          local cterm_color = util.hex_to_cterm(color)
          local r, g, b = util.hex_to_rgb(color)
          local luminance = util.get_luminance(r, g, b)
          local fg_color = (luminance > 0.179) and '#000000' or '#FFFFFF'
          local cterm_fg_color = (luminance > 0.179) and util.hex_to_cterm('#000000') or util.hex_to_cterm('#FFFFFF')
          vim.api.nvim_set_hl(0, group_name, { bg = color, ctermbg = cterm_color, fg = fg_color, ctermfg = cterm_fg_color })
          defined_highlights[group_name] = true
        end

        local priority_col_start = id_width + 2 + status_width + 2
        local priority_col_end = priority_col_start + priority_width
        table.insert(extmarks_to_apply, {
          line = #lines - 1, -- 0-indexed line number
          col_start = priority_col_start,
          col_end = priority_col_end,
          hl_group = group_name
        })
      end
    end
  end



  -- Empty line
  table.insert(lines, '')

  -- Keymap help area
  local keymap_help_text = "a: Assigned Issues | v: All Issues | q: Quit"
  local keymap_padding = math.floor((win_width - #keymap_help_text) / 2)
  table.insert(lines, string.rep(' ', keymap_padding) .. keymap_help_text)

  -- Store extmark details for MantisKeymapHelp
  local keymap_line_content = lines[#lines]
  local keymap_line_end_col = #keymap_line_content
  table.insert(extmarks_to_apply, {
    line = #lines - 1, -- 0-indexed line number
    col_start = 0,
    col_end = keymap_line_end_col,
    hl_group = 'MantisKeymapHelp'
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(win, { 5, 0 }) -- Restore cursor setting to the first issue line (1-indexed 5)

  -- Apply all stored extmarks after the buffer lines are set
  for _, detail in ipairs(extmarks_to_apply) do
    vim.api.nvim_buf_set_extmark(buf, mantis_ns, detail.line, detail.col_start, { end_col = detail.col_end, hl_group = detail.hl_group })
  end

  -- Key mappings (these do not need to be deferred)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'j', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      -- Cursor is 1-indexed for line, 0-indexed for col.
      -- Issues start at line 5 (1-indexed). Total lines before first issue is 4.
      if cursor[1] < (#M.issues + 4) then -- check if cursor is before last issue
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

  vim.api.nvim_buf_set_keymap(buf, 'n', 'a', '', {
    noremap = true,
    silent = true,
    callback = function()
      if M.active_view ~= "assigned" then
        M.show_assigned_issues(M.current_host, "assigned")
      end
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'v', '', {
    noremap = true,
    silent = true,
    callback = function()
      if M.active_view ~= "all" then
        M.show_assigned_issues(M.current_host, "all")
      end
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
    M.show_assigned_issues(host_names[1], "assigned")
    return
  end

  vim.ui.select(host_names, { prompt = 'Select a Mantis Host:' }, function(choice)
    if choice then
      M.show_assigned_issues(choice, "assigned")
    end
  end)
end

return M
