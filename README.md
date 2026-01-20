<img width="100%" alt="image" src="https://github.com/user-attachments/assets/3b2f8a9c-2810-4ec3-acd6-145bea3d1bdc" />

[MantisBT](https://mantisbt.org) plugin for Neovim.

## Features

- Supports multiple MantisBT hosts
- Fully reactive UI powered by **nui-components**
- Fast. Like, *why-is-this-Lua-so-fast* fast ⚡

### Issues

- Configurable issue properties
- Optional pagination for large result sets
- Assign issues to users
- Create and delete issues
- Open issues directly in your browser
- Update status, priority, severity, and category
- Add notes to existing issues

### Create Issue

- Assign users
- Set category
- Add summary and description

### View Issue

- Inspect full issue details
- Browse issue notes
- Review issue history


## Installation

This plugin relies on the following external dependencies:

*   [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
*   [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim)
*   [grapp-dev/nui-components.nvim](https://github.com/grapp-dev/nui-components.nvim)

You can install `mantis.nvim` and its dependencies using your preferred plugin manager.

### Example using `packer.nvim`:

```lua
use {
  'whleucka/mantis.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'grapp-dev/nui-components.nvim',
  },
}
```

## Configuration

To use `mantis.nvim`, you need to configure your MantisBT hosts. This is done by calling the `setup` function with a `hosts` table. Each host entry should include a `name` (for display), `url` (the base URL of your MantisBT instance), and either an `token` (your MantisBT API token directly) or an `env` (the name of an environment variable holding your API token).

### Example:

```lua
require('mantis').setup({
  hosts = {
    {
      name = "My MantisBT Instance",
      url = "https://mantis.host.com",
      token = "YOUR_API_TOKEN", -- Use this if you want to hardcode the token
    },
    {
      name = "Another MantisBT Instance",
      url = "https://your.mantishub.com/api/rest",
      env = "MANTIS_API_TOKEN", -- Use this to read the token from an environment variable
    },
  },
  -- Other optional configurations
})
```

### Default configuration

```lua
{
  debug = false,
  hosts = {},
  add_note = {
    ui = {
      width = 80,
      height = 15,
    },
    keymap = {
      quit = "q",
      submit = "<C-CR>",
    }
  },
  create_issue = {
    ui = {
      width = 80,
      height = 15,
    },
    keymap = {
      quit = "q",
      submit = "<C-CR>",
    }
  },
  view_issue = {
    ui = {
      width = 80,
      height = 30,
    },
    keymap = {
      quit = "q",
    }
  },
  view_issues = {
    limit = 40,
    ui = {
      width = 150,
      height = 50,
      columns = {
        priority = 1,
        id = 7,
        severity = 10,
        status = 24,
        category = 12,
        summary = 69,
        updated = 10
      }
    },
    keymap = {
      next_page = "L",
      prev_page = "H",
      add_note = "N",
      create_issue = "C",
      delete_issue = "D",
      open_issue = "o",
      assign_issue = "a",
      change_summary = "S",
      change_status = "s",
      change_severity = "v",
      change_priority = "p",
      change_category = "c",
      filter = "f",
      help = "?",
      refresh = "r",
      quit = "q",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
  issue_resolution_options = {},
  issue_filter_options = {
    'all',
    'assigned',
    'reported',
    'monitored',
    'unassigned',
  },
  priority_emojis = {
    complete = "✅",
    immediate = "🔥",
    urgent    = "‼️",
    high      = "❗",
    normal    = "⭐",
    low       = "🔻",
    default   = "❓"
  },
}
```

## Screenshots

<img width="1449" height="991" alt="image" src="https://github.com/user-attachments/assets/8c30bbfd-1590-4dd4-9763-d05b30eb96a3" />
