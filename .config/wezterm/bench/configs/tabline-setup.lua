-- Isolates tabline.setup() cost. Loads the same 3 plugins as plugins-only.lua, then runs a
-- representative tabline.setup(). Cold-startup delta vs plugins-only.lua = the tabline setup cost.
local wezterm = require("wezterm")
wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
tabline.setup({
  options = { theme = "Catppuccin Frappe", tabs_enabled = true },
  sections = {
    tabline_a = { "mode" }, tabline_b = { "workspace" }, tabline_c = { " " },
    tab_active = { "index", "process" }, tab_inactive = { "index", "process" },
    tabline_x = {}, tabline_y = {}, tabline_z = {},
  },
})
return {}
