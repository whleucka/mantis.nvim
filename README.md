# mantis.nvim

[MantisBT](https://mantisbt.org) plugin for Neovim.

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
  debug = false,
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
      toggle_time = "<C-t>",
    }
  },
  create_issue = {
    ui = {
      width = 80,
      height = 15,
    }
  },
  view_issue = {
    ui = {
      width = 80,
      height = 30,
    }
  },
  view_issues = {
    limit = 42,
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
      add_note = "n",
      create_issue = "c",
      delete_issue = "d",
      open_issue = "o",
      assign_issue = "a",
      change_summary = "S",
      change_status = "s",
      change_severity = "v",
      change_priority = "p",
      change_category = "t",
      filter = "f",
      help = "?",
      refresh = "r",
      quit = "q",
    }
  },
  issue_status_options = {},
  issue_severity_options = {},
  issue_priority_options = {},
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
    urgent    = "⚠️",
    high      = "🔴",
    normal    = "🟢",
    low       = "🔵",
    default   = "⚪"
  },
}
```

(This section will be expanded later)
