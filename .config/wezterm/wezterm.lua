--- @type Wezterm
local wezterm = require("wezterm")

local vim_smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action
local launch_menu = {}

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Frappe"
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.set_environment_variables = {}
config.front_end = "Software"

local ShellTypes = {
    NONE = 0,
    CMD = 1,
    CMDER = 2,
    PowerShell = 3,
    WSL = 4,
}

local shellType = ShellTypes.WSL
-- uncomment if I want to use clink only
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
    -- PowerShell 7
    table.insert(launch_menu, {
        label = "PowerShell 7",
        args = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- Windows PowerShell (5.1)
    table.insert(launch_menu, {
        label = "Windows PowerShell",
        args = { "powershell.exe", "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- WSL2 default distro
    table.insert(launch_menu, {
        label = "WSL2 (default)",
        args = { "wsl.exe" },
    })

    -- Cmder (adjust path to your actual cmder_root if needed)
    local cmder_root = os.getenv("cmder_root") or "C:\\tools\\cmder"
    table.insert(launch_menu, {
        label = "Cmder",
        args = { "cmd.exe", "/s", "/k", cmder_root .. "\\vendor\\init.bat" },
        domain = { DomainName = "local" },
    })

    -- because my tmux on macos have bottom tab bar
    config.tab_bar_at_bottom = true
    if shellType == ShellTypes.CMD then
        -- Use OSC 7 as per the above example
        config.set_environment_variables["prompt"] =
            "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
        -- use a more ls-like output format for dir
        -- And inject clink into the command prompt
        config.set_environment_variables["DIRCMD"] = "/d"
    end

    if shellType == ShellTypes.CMDER then
        config.default_prog = { "cmd.exe", "/s", "/k", "c:/clink/clink_x64.exe", "inject", "-q" }

        -- bring color to default cmd
        config.set_environment_variables = {
            prompt = "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m ",
        }

        local initBat = os.getenv("cmder_root") .. "\\vendor\\init.bat"
        -- TODO: might need to remove
        config.set_environment_variables["prompt"] =
            "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
        -- TODO: might need to remove
        config.set_environment_variables["DIRCMD"] = "/d"
        config.default_prog = { "cmd.exe", "/s", "/k", initBat }
    end

    if shellType == ShellTypes.PowerShell then
        config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" }
    end

    if shellType == ShellTypes.WSL then
        config.default_domain = "WSL:Ubuntu"
        config.default_prog = {
            "wsl.exe",
            "--distribution",
            "Ubuntu",
            "--cd",
            "~",
        }
    end
end

-- unbind alt enter
config.keys = {
    { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "u", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "d", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
}

if wezterm.target_triple == "x86_64-pc-windows-msvc" and shellType ~= ShellTypes.WSL then
    config.leader = {
        key = " ",
        mods = "CTRL",
        timeout_milliseconds = 1000,
    }

    -- local direction_keys = {
    --     h = "Left",
    --     j = "Down",
    --     k = "Up",
    --     l = "Right",
    -- }
    -- local function split_nav(key)
    --     return {
    --         key = key,
    --         mods = "CTRL",
    --         action = wezterm.action_callback(function(win, pane)
    --             if pane.Get_users_vars ~= nil and type(pane.Get_users.vars) == "function" then
    --                 -- pass the keys through to vim/nvim
    --                 if pane:Get_users_vars().IS_NVIM == "true" then
    --                   win:perform_action({
    --                       SendKey = { key = key, mods = "CTRL" },
    --                   }, pane)
    --                 end
    --             else
    --                 win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
    --             end
    --         end),
    --     }
    -- end

    config.keys = {
        {
            key = "T",
            mods = "LEADER|SHIFT",
            action = act.ShowLauncher,
        },
        -- CTRL-SHIFT-l activates the debug overlay
        { key = "L", mods = "CTRL", action = wezterm.action.ShowDebugOverlay },
        -- Split horizontal
        {
            key = "|",
            mods = "LEADER|SHIFT",
            action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
        },
        {
            key = "v",
            mods = "LEADER",
            action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
        },
        -- Split Vertical
        {
            key = "-",
            mods = "LEADER|SHIFT",
            action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }),
        },
        {
            key = "s",
            mods = "LEADER",
            action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }),
        },
        -- Move between panes, mimic 'christoome/vim-tmux-navigator'
        -- split_nav("h"),
        -- split_nav("j"),
        -- split_nav("k"),
        -- split_nav("l"),
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
        {
            key = "s",
            mods = "LEADER|SHIFT",
            action = wezterm.action.ShowLauncherArgs({ flags = "WORKSPACES" }),
        },
        {
            key = "x",
            mods = "LEADER",
            action = wezterm.action({ CloseCurrentPane = { confirm = true } }),
        },
        {
            key = "&",
            mods = "LEADER|SHIFT",
            action = wezterm.action({ CloseCurrentTab = { confirm = true } }),
        },
        {
            key = ",",
            mods = "LEADER",
            action = wezterm.action.PromptInputLine({
                description = "Enter new name for tab",
                action = wezterm.action_callback(function(window, pane, line)
                    if line then
                        window:active_tab():set_title(line)
                    end
                end),
            }),
        },
        {
            key = "t",
            mods = "LEADER",
            action = wezterm.action.SpawnTab("CurrentPaneDomain"),
        },
        {
            key = "p",
            mods = "LEADER",
            action = wezterm.action.ActivateTabRelative(-1),
        },
        {
            key = "n",
            mods = "LEADER",
            action = wezterm.action.ActivateTabRelative(1),
        },
    }

    -- tab switching
    for i = 1, 9 do
        table.insert(config.keys, {
            key = tostring(i),
            mods = "LEADER",
            action = wezterm.action.ActivateTab(i - 1),
        })
    end
    -- Create a status bar on the top right that shows the current workspace and date
    ---comment
    ---@param window Window
    ---@param pane Pane
    wezterm.on("update-right-status", function(window, pane)
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

    -- vim smart splits
    vim_smart_splits.apply_to_config(config, {
        -- directional keys to use in order of: left, down, up, right
        -- separate direction keys for move vs. resize
        direction_keys = {
            move = { "h", "j", "k", "l" },
            resize = { "LeftArrow", "DownArrow", "UpArrow", "RightArrow" },
        },
        -- modifier keys to combine with direction_keys
        modifiers = {
            move = "CTRL", -- modifier to use for pane movement, e.g. CTRL+h to move left
            resize = "META", -- modifier to use for pane resize, e.g. META+h to resize to the left
        },
        -- log level to use: info, warn, error
        log_level = "info",
    })
end

-- local font_family = "JetBrains Mono" -- or JetBrainsMono Nerd Font, Fira Code
local font = wezterm.font_with_fallback({
    "JetBrains Mono",
    "JetBrainsMono Nerd Font",
})
local macbookFontSize = 13
local windowsFontSize = 10
local isMacOS = (wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin")
    or false
config.font = font
config.font_size = isMacOS and macbookFontSize or windowsFontSize

--ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
config.freetype_load_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
config.freetype_render_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'

config.inactive_pane_hsb = {
    hue = 0.5,
    saturation = 0.5,
    brightness = 0.6,
}

config.launch_menu = launch_menu
-- and finally, return the configuration to wezterm
return config
