# Presenterm.nvim

a fork of [presenterm.nvim](https://github.com/marianozunino/presenterm.nvim) by marianozunino

## Requirements

- presenterm (tested with 0.14.0)

## Features

- Launch Preview in snacks terminal
- Launch PDF export

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
  {
    "burgr033/presenterm.nvim",
    ft = "markdown", -- lazy-load on markdown files
    opts = {},       -- optional: pass config options
    config = function(_, opts)
      require("presenterm").setup(opts)

      -- Define mappings only after the plugin is loaded (for markdown)
      vim.keymap.set("n", "<localleader>e", function()
        require("presenterm").export_pdf()
      end, { desc = "Export presentation as PDF", buffer = true })

      vim.keymap.set({ "n", "t" }, "<localleader>p", function()
        local count = vim.v.count > 0 and vim.v.count or nil
        if vim.fn.mode() == "t" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        end
        require("presenterm").toggle_preview(count)
      end, { desc = "Toggle preview (with optional slide number)", buffer = true })    end
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
