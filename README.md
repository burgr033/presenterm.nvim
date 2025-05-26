# Presenterm.nvim

a fork of [presenterm.nvim](https://github.com/marianozunino/presenterm.nvim) by marianozunino

## Features

- Launch Preview in snacks terminal
- Launch PDF export

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "burgr033/presenterm.nvim",
  ft = "markdown",
  config = function()
    require("presenterm").setup({})
  end
}
```

## Configuration

No configuration needed. You just need to open up any \*.md file

## Commands

- `PTExportPDF` launches presenterm with -e to export to pdf
- `PTTogglePreview` toggles a preview window in snacks.terminal

# Acknowledgements

- marianozunino for creating the original [presenterm.nvim](https://github.com/marianozunino/presenterm.nvim)
- mfontanini for creating the aweseome [presenterm](https://github.com/mfontanini/presenterm)
- folke for [basically](https://github.com/folke/lazy.nvim) [everything](https://github.com/folke/snacks.nvim)
