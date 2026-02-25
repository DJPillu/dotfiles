return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      on_highlights = function(hl, c)
        -- Make common UI bars & popups transparent
        local none = { bg = "NONE" }

        hl.StatusLine = none
        hl.StatusLineNC = none
        hl.WinBar = none
        hl.WinBarNC = none
        hl.TabLine = none
        hl.TabLineFill = none
        hl.TabLineSel = none

        -- Popup menu (completion)
        hl.Pmenu = none
        hl.PmenuSel = none
        hl.PmenuSbar = none
        hl.PmenuThumb = none

        -- Optional: borders for floating windows
        hl.FloatBorder = none
      end,
    },
  },
}