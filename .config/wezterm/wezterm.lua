-- Pull in the wezterm API
--- @type Wezterm
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Frappe"

config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

config.set_environment_variables = {}
-- uncomment if I want to use clink only
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	if false then
		-- Use OSC 7 as per the above example
		config.set_environment_variables["prompt"] =
			"$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
		-- use a more ls-like output format for dir
		-- And inject clink into the command prompt
		config.set_environment_variables["DIRCMD"] = "/d"
	end
	config.default_prog = { "cmd.exe", "/s", "/k", "c:/clink/clink_x64.exe", "inject", "-q" }

	-- bring color to default cmd
	config.set_environment_variables = {
		prompt = "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m ",
	}

	local initBat = os.getenv("cmder_root") .. "\\vendor\\init.bat"
	-- TODO: might need to remove
	config.set_environment_variables["prompt"] = "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
	-- TODO: might need to remove
	config.set_environment_variables["DIRCMD"] = "/d"
	config.default_prog = { "cmd.exe", "/s", "/k", initBat }
end

-- unbind alt enter
config.keys = {
	{ key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
}

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.leader = {
		key = "\\",
		mods = "CTRL",
		timeout_milliseconds = 1000,
	}
	config.keys = {
		-- CTRL-SHIFT-l activates the debug overlay
		{ key = "L", mods = "CTRL", action = wezterm.action.ShowDebugOverlay },
		-- Split horizontal
		{
			key = "|",
			mods = "LEADER|SHIFT",
			action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
		},
		-- Split Vertical
		{
			key = "-",
			mods = "LEADER|SHIFT",
			action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }),
		},
		-- Move between panes
		{ key = "h", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
		{ key = "j", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
		{ key = "k", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
		{ key = "l", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
		-- Switch to new or existing workspace
		-- Similar to when you attach to or switch tmux sessions
		{
			key = "W",
			mods = "LEADER|SHIFT",
			action = wezterm.action.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Enter name for new workspace." },
				}),
				action = wezterm.action_callback(function(window, pane, line)
					-- line will be `nil` if they hit escape without entering anything
					-- An empty string if they just hit enter
					-- Or the actual line of text they wrote
					if line then
						window:perform_action(
							wezterm.action.SwitchToWorkspace({
								name = line,
							}),
							pane
						)
					end
				end),
			}),
		},
	}

	-- Create a status bar on the top right that shows the current workspace and date
	wezterm.on("update-right-status", function(window, _)
		local date = wezterm.strftime("%d-%m-%Y %H:%M:%S")

		-- Make it italic and underlined
		window:set_right_status(wezterm.format({
			{ Attribute = { Underline = "Single" } },
			{ Attribute = { Italic = true } },
			{ Attribute = { Intensity = "Bold" } },
			{ Foreground = { AnsiColor = "Fuchsia" } },
			{ Text = window:active_workspace() },
			{ Text = "   " },
			{ Text = date },
		}))
	end)
end

local font_family = "JetBrainsMono Nerd Font"
local font = wezterm.font({
	family = font_family,
	weight = "Medium",
})
config.font = font
config.font_size = (wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin")
		and 12
	or 9

--ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
config.freetype_load_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
config.freetype_render_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'

config.inactive_pane_hsb = {
	hue = 0.5,
	saturation = 0.5,
	brightness = 0.6,
}

-- and finally, return the configuration to wezterm
return config
