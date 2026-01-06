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


local function open_float_win()
  local width = vim.api.nvim_get_option('columns')
  local height = vim.api.nvim_get_option('lines')

  local win_width = math.floor(width * 0.9)
  local win_height = math.floor(height * 0.9)

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

function M.show_assigned_issues(host_name)
  local client = mantis.new(host_name)
  if not client then
    return
  end
  -- For now we get my assigned issues, we can add more options later
  local issues_data = client:get_my_assigned_issues()
  if not issues_data or not issues_data.issues or #issues_data.issues == 0 then
    vim.notify('No assigned issues found for host: ' .. host_name, vim.log.levels.INFO)
    return
  end

  M.issues = issues_data.issues

  local buf, win = open_float_win()

  local lines = {}
  table.insert(lines, string.format('%-2s %-10s %-15s %-20s %-20s %-50s %-20s', '', 'ID', 'Status', 'Project', 'Category', 'Summary', 'Updated'))
  for _, issue in ipairs(M.issues) do
    local id = tostring(issue.id)
    local status = issue.status.name
    local project = issue.project.name
    local category = issue.category.name
    local summary = issue.summary
    local updated = parse_iso_date(issue.updated_at)
    table.insert(lines, string.format('%-2s %-10s %-15s %-20s %-20s %-50s %-20s', '■', id, status, project, category, summary, updated))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(win, { 2, 0 })

  local defined_highlights = {}

  for i, issue in ipairs(M.issues) do
    if issue.status and issue.status.color then
      local color = issue.status.color
      local group_name = 'MantisStatus_' .. color:sub(2)

      if not defined_highlights[group_name] then
        local cterm_color = util.hex_to_cterm(color)
        vim.api.nvim_set_hl(0, group_name, { fg = color, ctermfg = cterm_color })
        defined_highlights[group_name] = true
      end

      -- Highlight the box character
      -- The line number is i, because the header is at line 0, and issues start at line 1
      -- The box column starts at character 0 and has a length of 1
      vim.api.nvim_buf_add_highlight(buf, -1, group_name, i, 0, 1)
    end
  end

  -- Key mappings
  vim.api.nvim_buf_set_keymap(buf, 'n', 'j', 'j', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'k', 'k', { noremap = true, silent = true })
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
