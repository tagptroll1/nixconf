-- Palette for the current Omarchy theme, rendered by omarchy-theme-set-templates.
-- Upstream ships a LazyVim plugin spec here; config/nvim is vim.pack, so this is a
-- bare table instead. init.lua dofile()s it and hands it to aether.nvim's setup().
return {
  bg = "{{ background }}",
  dark_bg = "{{ dark_background }}",
  darker_bg = "{{ darker_background }}",
  lighter_bg = "{{ lighter_background }}",

  fg = "{{ foreground }}",
  dark_fg = "{{ dark_foreground }}",
  light_fg = "{{ light_foreground }}",
  bright_fg = "{{ bright_foreground }}",
  muted = "{{ muted }}",

  red = "{{ red }}",
  yellow = "{{ yellow }}",
  orange = "{{ orange }}",
  green = "{{ green }}",
  cyan = "{{ cyan }}",
  blue = "{{ blue }}",
  magenta = "{{ magenta }}",
  purple = "{{ purple }}",
  brown = "{{ brown }}",

  bright_red = "{{ bright_red }}",
  bright_yellow = "{{ bright_yellow }}",
  bright_green = "{{ bright_green }}",
  bright_cyan = "{{ bright_cyan }}",
  bright_blue = "{{ bright_blue }}",
  bright_magenta = "{{ bright_magenta }}",
  bright_purple = "{{ bright_purple }}",

  accent = "{{ accent }}",
  cursor = "{{ cursor }}",
  foreground = "{{ foreground }}",
  background = "{{ background }}",
  selection = "{{ selection }}",
  selection_foreground = "{{ selection_foreground }}",
  selection_background = "{{ selection_background }}",
}
