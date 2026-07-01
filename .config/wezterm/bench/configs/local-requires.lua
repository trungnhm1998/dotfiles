-- Isolates the load+eval cost of the config's local modules. Adds the real config dir to the Lua
-- path, then requires the 5 self-contained ones. Cold-startup delta vs empty.lua = local-require cost.
-- (tabline_claude_badge is omitted: it depends on tabline internals set up by tabline.setup.)
package.path = package.path .. ';C:/Users/mint/dotfiles/.config/wezterm/?.lua'
require("wezterm_remotes")
require("wezterm_status")
require("wezterm_mux_detect")
require("wezterm_claude_alerts")
require("wezterm_claude_focus")
return {}
