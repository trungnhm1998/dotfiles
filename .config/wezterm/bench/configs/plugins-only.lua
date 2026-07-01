-- Isolates the load+eval cost of the three plugins the real config requires.
-- Compare startup of this vs empty.lua to attribute pure plugin-load cost.
local wezterm = require("wezterm")
wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
return {}
