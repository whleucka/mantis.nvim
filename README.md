# mantis-nvim

A Neovim client for MantisBT.

## Installation

This plugin relies on the following external dependencies:

*   [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
*   [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim)
*   [MunifTanjim/nui-components.nvim](https://github.com/MunifTanjim/nui-components.nvim)

You can install `mantis-nvim` and its dependencies using your preferred plugin manager.

### Example using `packer.nvim`:

```lua
use {
  'your-github-username/mantis-nvim', -- Replace with the actual repository
  requires = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'MunifTanjim/nui-components.nvim',
  },
}
```

## Configuration

To use `mantis-nvim`, you need to configure your MantisBT hosts. This is done by calling the `setup` function with a `hosts` table. Each host entry should include a `name` (for display), `url` (the base URL of your MantisBT instance), and either an `token` (your MantisBT API token directly) or an `env` (the name of an environment variable holding your API token).

### Example:

```lua
require('mantis').setup({
  hosts = {
    {
      name = "My MantisBT Instance",
      url = "https://your.mantishub.com/api/rest",
      token = "YOUR_API_TOKEN", -- Use this if you want to hardcode the token
    },
    {
      name = "Another MantisBT Instance",
      url = "https://another.mantishub.com/api/rest",
      env = "MANTIS_API_TOKEN", -- Use this to read the token from an environment variable
    },
  },
  -- Other optional configurations
  debug = false,
})
```

## Usage

(This section will be expanded later)
