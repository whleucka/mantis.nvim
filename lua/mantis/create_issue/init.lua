local M = {}

local ui = require("mantis.ui")
local n = require("nui-components")
local state = require("mantis.state")
local config = require("mantis.config")
local options = config.options.create_issue
local helper = require("mantis.create_issue.helper")

local signal = n.create_signal({
  project_id = nil,
  summary = "",
  description = "",
  category_name = "",
  handler_name = "",
  priority_name = "",
  severity_name = "",
  reproducibility_name = "",
})

local renderer = n.create_renderer({
  width = options.ui.width,
  height = options.ui.height,
  keymap = {
    close = options.keymap.quit,
  },
  on_unmount = function()
    ui.view_issues()
  end,
})

local function get_users()
  local project_id = signal.project_id:get_value()
  local nodes = {}
  local ok, res = state.api:get_project_users(project_id)
  if not ok then
    return nodes
  end

  for i, user in ipairs(res.users) do
    if i == 1 then
      signal.handler_name = user.name
    end
    table.insert(nodes, n.option(user.name, { id = user.name }))
  end

  return nodes
end

local function get_categories()
  local project_id = signal.project_id:get_value()
  local nodes = {}
  local ok, categories = state.api:get_project_categories(project_id)
  if not ok then
    return nodes
  end

  for i, category in ipairs(categories) do
    if i == 1 then
      signal.category_name = category.name
    end
    table.insert(nodes, n.option(category.name, { id = category.name }))
  end

  return nodes
end

local function get_priorities()
  local nodes = {}
  local opts = config.options.issue_priority_options
  if #opts == 0 then
    table.insert(nodes, n.option("normal", { id = "normal" }))
    signal.priority_name = "normal"
  else
    -- Put "normal" first, then the rest
    for _, opt in ipairs(opts) do
      if opt.name == "normal" then
        table.insert(nodes, 1, n.option(opt.name, { id = opt.name }))
      else
        table.insert(nodes, n.option(opt.name, { id = opt.name }))
      end
    end
    signal.priority_name = "normal"
  end
  return nodes
end

local function get_severities()
  local nodes = {}
  local opts = config.options.issue_severity_options
  if #opts == 0 then
    table.insert(nodes, n.option("minor", { id = "minor" }))
    signal.severity_name = "minor"
  else
    for i, opt in ipairs(opts) do
      if i == 1 then
        signal.severity_name = opt.name
      end
      table.insert(nodes, n.option(opt.name, { id = opt.name }))
    end
  end
  return nodes
end

local function get_reproducibilities()
  local nodes = {}
  local opts = config.options.issue_reproducibility_options
  if #opts == 0 then
    table.insert(nodes, n.option("always", { id = "always" }))
    signal.reproducibility_name = "always"
  else
    for i, opt in ipairs(opts) do
      if i == 1 then
        signal.reproducibility_name = opt.name
      end
      table.insert(nodes, n.option(opt.name, { id = opt.name }))
    end
  end
  return nodes
end

local body = function()
  local keymap = options.keymap

  return n.form(
    {
      id = "form",
      submit_key = keymap.submit,
      on_submit = function(is_valid)
        if is_valid then
          local s = signal:get_value()
          local data = {
            summary = s.summary,
            description = s.description,
            category = {
              name = s.category_name
            },
            project = {
              id = s.project_id
            },
            handler = {
              name = s.handler_name
            },
            priority = {
              name = s.priority_name
            },
            severity = {
              name = s.severity_name
            },
            reproducibility = {
              name = s.reproducibility_name
            }
          }
          local ok, _ = state.api:create_issue(data)
          if not ok then
            vim.notify("Could not create issue", vim.log.levels.ERROR)
            renderer:close()
            return
          end
          vim.notify("Issue successfully created", vim.log.levels.INFO)
          renderer:close()
          signal.summary = ""
          signal.description = ""
          signal.category_name = ""
          signal.handler_name = ""
          signal.priority_name = ""
          signal.severity_name = ""
          signal.reproducibility_name = ""
        end
      end,
    },
    n.columns(
      { size = 1 },
      n.select({
        autofocus = true,
        flex = 1,
        border_label = "Assigned User",
        selected = signal.handler_name,
        data = get_users(),
        on_change = function(node)
          signal.handler_name = node.id
        end,
      }),
      n.select({
        flex = 1,
        border_label = "Category",
        selected = signal.category_name,
        data = get_categories(),
        on_change = function(node)
          signal.category_name = node.id
        end,
      }),
      n.select({
        flex = 1,
        border_label = "Priority",
        selected = signal.priority_name,
        data = get_priorities(),
        on_change = function(node)
          signal.priority_name = node.id
        end,
      })
    ),
    n.columns(
      { size = 1 },
      n.select({
        flex = 1,
        border_label = "Severity",
        selected = signal.severity_name,
        data = get_severities(),
        on_change = function(node)
          signal.severity_name = node.id
        end,
      }),
      n.select({
        flex = 1,
        border_label = "Reproducibility",
        selected = signal.reproducibility_name,
        data = get_reproducibilities(),
        on_change = function(node)
          signal.reproducibility_name = node.id
        end,
      })
    ),
    n.text_input({
      autofocus = false,
      autoresize = true,
      value = signal.summary,
      border_label = "Summary",
      max_lines = 1,
      validate = n.validator.min_length(1),
      on_change = function(value, component)
        signal.summary = value
      end
    }),
    n.text_input({
      autofocus = false,
      autoresize = true,
      size = 12,
      value = signal.description,
      border_label = "Description",
      validate = n.validator.min_length(1),
      on_change = function(value, component)
        signal.description = value
      end,
      on_mount = function(component)
        component:set_border_text("bottom", " " .. keymap.quit .. ": quit | " .. keymap.submit .. ": submit ", "right")
      end,
    })
  )
end

function M.render(project_id)
  signal.project_id = project_id
  renderer:render(body)
end

return M
