local M = {}

local timezone_offset = (function()
  local now = os.time()
  local local_t = os.date("*t", now)
  local utc_t = os.date("!*t", now)
  local_t.isdst = false
  return os.difftime(os.time(local_t), os.time(utc_t))
end)()

local function parse_iso8601(ts)
  local date, time = ts:match("^(%d+-%d+-%d+)T(%d+:%d+:%d+)")
  if not date or not time then
    return nil
  end

  local y, m, d = date:match("(%d+)-(%d+)-(%d+)")
  local hh, mm, ss = time:match("(%d+):(%d+):(%d+)")

  return os.time({
    year  = tonumber(y),
    month = tonumber(m),
    day   = tonumber(d),
    hour  = tonumber(hh),
    min   = tonumber(mm),
    sec   = tonumber(ss),
    isdst = false,
  }) + timezone_offset
end

function M.format_datetime(ts)
  if not ts then return "N/A" end
  local epoch = parse_iso8601(ts)
  if not epoch then return ts end
  return os.date("%Y-%m-%d %H:%M", epoch)
end

function M.time_ago(ts)
  if not ts then return "?" end
  local epoch = parse_iso8601(ts)
  if not epoch then return "?" end

  local diff = os.time() - epoch

  if diff < 60 then
    return diff .. "s ago"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h ago"
  elseif diff < 604800 then
    return math.floor(diff / 86400) .. "d ago"
  else
    return math.floor(diff / 604800) .. "w ago"
  end
end

function M.wrap_text(text, width)
  if not text or text == "" then return {} end

  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    if #line <= width then
      table.insert(lines, line)
    else
      local current = ""
      for word in line:gmatch("%S+") do
        if #current + #word + 1 <= width then
          current = current == "" and word or (current .. " " .. word)
        else
          if current ~= "" then
            table.insert(lines, current)
          end
          if #word > width then
            while #word > width do
              table.insert(lines, word:sub(1, width))
              word = word:sub(width + 1)
            end
            current = word
          else
            current = word
          end
        end
      end
      if current ~= "" then
        table.insert(lines, current)
      end
    end
  end

  return lines
end

function M.format_issue_header(issue, width)
  local lines = {}
  local sep = string.rep("─", width - 2)

  table.insert(lines, { text = " " .. issue.summary, hl = "Title" })
  table.insert(lines, { text = sep, hl = "Comment" })
  table.insert(lines, { text = "" })

  local function add_field(label, value, hl)
    local text = string.format("  %-12s %s", label .. ":", value or "N/A")
    table.insert(lines, { text = text, hl = hl or "Normal" })
  end

  add_field("ID", tostring(issue.id), "Number")
  add_field("Project", issue.project and issue.project.name, "Directory")
  add_field("Category", issue.category and issue.category.name, "Type")
  add_field("Status", issue.status and issue.status.label, "MantisStatus")
  add_field("Resolution", issue.resolution and issue.resolution.label, "Keyword")
  add_field("Priority", issue.priority and issue.priority.label, "WarningMsg")
  add_field("Severity", issue.severity and issue.severity.label, "Identifier")
  add_field("Reporter", issue.reporter and (issue.reporter.real_name or issue.reporter.name), "String")

  local handler_name = "Unassigned"
  if issue.handler then
    handler_name = issue.handler.real_name or issue.handler.name
  end
  add_field("Handler", handler_name, "Function")

  add_field("Created", M.format_datetime(issue.created_at), "Comment")
  add_field("Updated", M.format_datetime(issue.updated_at) .. " (" .. M.time_ago(issue.updated_at) .. ")", "Comment")

  return lines
end

function M.format_description(issue, width)
  local lines = {}
  local sep = string.rep("─", width - 2)

  table.insert(lines, { text = "" })
  table.insert(lines, { text = " Description", hl = "Title" })
  table.insert(lines, { text = sep, hl = "Comment" })

  local desc = issue.description or "No description provided."
  local wrapped = M.wrap_text(desc, width - 4)
  for _, line in ipairs(wrapped) do
    table.insert(lines, { text = "  " .. line, hl = "Normal" })
  end

  return lines
end

function M.format_custom_fields(issue, width)
  if not issue.custom_fields or #issue.custom_fields == 0 then
    return {}
  end

  local lines = {}
  local sep = string.rep("─", width - 2)

  table.insert(lines, { text = "" })
  table.insert(lines, { text = " Custom Fields", hl = "Title" })
  table.insert(lines, { text = sep, hl = "Comment" })

  for _, cf in ipairs(issue.custom_fields) do
    local name = cf.field and cf.field.name or "Unknown"
    local value = cf.value or "N/A"
    table.insert(lines, { text = string.format("  %-20s %s", name .. ":", value), hl = "Normal" })
  end

  return lines
end

function M.format_notes(issue, width)
  if not issue.notes or #issue.notes == 0 then
    return {}
  end

  local lines = {}
  local sep = string.rep("─", width - 2)

  table.insert(lines, { text = "" })
  table.insert(lines, { text = string.format(" Notes (%d)", #issue.notes), hl = "Title" })
  table.insert(lines, { text = sep, hl = "Comment" })

  for i, note in ipairs(issue.notes) do
    local reporter = note.reporter and (note.reporter.real_name or note.reporter.name) or "Unknown"
    local time = M.format_datetime(note.created_at) .. " (" .. M.time_ago(note.created_at) .. ")"

    table.insert(lines, { text = "" })
    table.insert(lines, { text = string.format("  [%d] %s", i, reporter), hl = "Function" })
    table.insert(lines, { text = "  " .. time, hl = "Comment" })
    table.insert(lines, { text = "" })

    local note_text = note.text or ""
    local wrapped = M.wrap_text(note_text, width - 6)
    for _, line in ipairs(wrapped) do
      table.insert(lines, { text = "    " .. line, hl = "Normal" })
    end

    if i < #issue.notes then
      table.insert(lines, { text = "" })
      table.insert(lines, { text = "  " .. string.rep("·", width - 6), hl = "Comment" })
    end
  end

  return lines
end

function M.format_history(issue, width)
  if not issue.history or #issue.history == 0 then
    return {}
  end

  local lines = {}
  local sep = string.rep("─", width - 2)

  table.insert(lines, { text = "" })
  table.insert(lines, { text = string.format(" History (%d)", #issue.history), hl = "Title" })
  table.insert(lines, { text = sep, hl = "Comment" })

  local display_count = math.min(#issue.history, 10)
  for i = 1, display_count do
    local entry = issue.history[i]
    local user = entry.user and (entry.user.real_name or entry.user.name) or "System"
    local time = M.time_ago(entry.created_at)
    local msg = entry.message or (entry.type and entry.type.name) or "Unknown action"

    table.insert(lines, { text = string.format("  %s - %s (%s)", time, msg, user), hl = "Comment" })
  end

  if #issue.history > 10 then
    table.insert(lines, { text = string.format("  ... and %d more entries", #issue.history - 10), hl = "Comment" })
  end

  return lines
end

function M.format_issue(issue, width)
  local all_lines = {}

  local sections = {
    M.format_issue_header(issue, width),
    M.format_description(issue, width),
    M.format_custom_fields(issue, width),
    M.format_notes(issue, width),
    M.format_history(issue, width),
  }

  for _, section in ipairs(sections) do
    for _, line in ipairs(section) do
      table.insert(all_lines, line)
    end
  end

  table.insert(all_lines, { text = "" })

  return all_lines
end

return M
