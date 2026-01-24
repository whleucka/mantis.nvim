<img width="100%" height="90" alt="image" src="https://github.com/user-attachments/assets/a790556a-e7d6-4eb7-b46b-89c1e8cad117" />

[MantisBT](https://mantisbt.org) plugin for Neovim.

## Features

- Supports multiple MantisBT hosts
- Fully reactive UI powered by **nui-components**
- Cross-platform (Linux, macOS, Windows)

### Issues

- Configurable issue properties
- Optional pagination for large result sets
- Assign issues to users
- Create and delete issues
- Open issues directly in your browser
- Update status, priority, severity, and category
- Add notes to existing issues
- Toggle grouped/ungrouped view

### Create Issue

- Assign users
- Set category
- Add summary and description

### View Issue

- Inspect full issue details
- Browse issue notes
- Review issue history

## Requirements

- Neovim 0.9.0 or higher
- MantisBT server with REST API enabled (v2.0+)

## Installation

This plugin relies on the following external dependencies:

*   [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
*   [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim)
*   [grapp-dev/nui-components.nvim](https://github.com/grapp-dev/nui-components.nvim)

### Using lazy.nvim

```lua
{
  'whleucka/mantis.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'grapp-dev/nui-components.nvim',
  },
  config = function()
    require('mantis').setup({
      hosts = {
        {
          name = "My MantisBT",
          url = "https://mantis.example.com",
          env = "MANTIS_API_TOKEN",
        },
      },
    })
  end,
}
```

### Using packer.nvim

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

To use `mantis.nvim`, you need to configure your MantisBT hosts. Each host entry should include:

- `name` (optional): Display name for the host
- `url` (required): Base URL of your MantisBT instance (without `/api/rest`)
- `token` or `env` (required): Either a hardcoded API token or the name of an environment variable containing the token

### Getting an API Token

1. Log in to your MantisBT instance
2. Go to **My Account** → **API Tokens**
3. Create a new token with appropriate permissions
4. Copy the token and store it securely

### Example Configuration

```lua
require('mantis').setup({
  hosts = {
    {
      name = "Work MantisBT",
      url = "https://mantis.company.com",
      env = "WORK_MANTIS_TOKEN", -- Reads from environment variable
    },
    {
      name = "Personal MantisBT",
      url = "https://my.mantisbt.org",
      token = "your-api-token-here", -- Hardcoded token (less secure)
    },
  },
})
```

### Default Configuration

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
      refresh = "r",
      scroll_down = "j",
      scroll_up = "k",
      page_down = "<C-d>",
      page_up = "<C-u>",
      goto_top = "gg",
      goto_bottom = "G",
    }
  },
  view_issues = {
    limit = 42, -- issues per page
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
      toggle_group = "g",
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
    complete  = "✅",
    immediate = "🔥",
    urgent    = "⚠️",
    high      = "🔺",
    normal    = "🔵",
    low       = "🔻",
    default   = "🟣",
  },
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:MantisIssues` | Open the issues view |
| `:MantisSelectHost` | Switch between configured hosts |

### Keymaps (Issues View)

| Key | Action |
|-----|--------|
| `?` | Toggle help |
| `<CR>` | View issue details |
| `o` | Open issue in browser |
| `C` | Create new issue |
| `N` | Add note to issue |
| `D` | Delete issue |
| `a` | Assign issue |
| `s` | Change status |
| `p` | Change priority |
| `v` | Change severity |
| `c` | Change category |
| `S` | Change summary |
| `f` | Filter issues |
| `g` | Toggle group by project |
| `r` | Refresh |
| `L` | Next page |
| `H` | Previous page |
| `q` | Quit |

### Keymaps (Issue View)

| Key | Action |
|-----|--------|
| `j` / `k` | Scroll down/up |
| `<C-d>` / `<C-u>` | Page down/up |
| `gg` / `G` | Go to top/bottom |
| `r` | Refresh |
| `q` | Quit |

## Troubleshooting

### "Environment variable not set" error

Make sure the environment variable specified in your `env` config is set before starting Neovim:

```bash
export MANTIS_API_TOKEN="your-token-here"
nvim
```

### API errors

- Verify your MantisBT URL is correct (should not include `/api/rest`)
- Check that your API token has the required permissions
- Ensure your MantisBT server has the REST API enabled

### Connection issues

- Check your network connection
- Verify the MantisBT server is accessible
- If using HTTPS, ensure SSL certificates are valid

## Screenshots

<img width="1449" height="991" alt="image" src="https://github.com/user-attachments/assets/8c30bbfd-1590-4dd4-9763-d05b30eb96a3" />
<img width="922" height="696" alt="image" src="https://github.com/user-attachments/assets/5648de5b-24af-41d3-bcef-3e40384f5960" />
<img width="877" height="517" alt="image" src="https://github.com/user-attachments/assets/01b4b97a-ab73-42fb-b16f-109b1e89f8e5" />


## License

MIT
