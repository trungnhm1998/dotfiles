--- @type Wezterm
local wezterm = require("wezterm")

local vim_smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

-- max fps
config.max_fps = 240
config.animation_fps = 240
local launch_menu = {}

config.color_scheme = "Catppuccin Frappe"
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_and_split_indices_are_zero_based = false
config.set_environment_variables = {}
config.front_end = "Software"
config.notification_handling = "AlwaysShow"

-- Catppuccin Frappe color palette
local scheme_colors = {
    rosewater = "#f2d5cf",
    flamingo = "#eebebe",
    pink = "#f4b8e4",
    mauve = "#ca9ee6",
    red = "#e78284",
    maroon = "#ea999c",
    peach = "#ef9f76",
    yellow = "#e5c890",
    green = "#a6d189",
    teal = "#81c8be",
    sky = "#99d1db",
    sapphire = "#85c1dc",
    blue = "#8caaee",
    lavender = "#babbf1",
    text = "#c6d0f5",
    subtext1 = "#b5bfe2",
    subtext0 = "#a5adce",
    overlay2 = "#949cbb",
    overlay1 = "#838ba7",
    overlay0 = "#737994",
    surface2 = "#626880",
    surface1 = "#51576d",
    surface0 = "#414559",
    base = "#303446",
    mantle = "#292c3c",
    crust = "#232634",
}

-- Colors for UI elements
local colors = {
    border = scheme_colors.lavender,
    tab_bar_active_tab_fg = scheme_colors.mauve,
    tab_bar_active_tab_bg = scheme_colors.crust,
    tab_bar_text = scheme_colors.crust,
    arrow_foreground_leader = scheme_colors.lavender,
    arrow_background_leader = scheme_colors.crust,
}

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
        domain = { DomainName = "WSL:Ubuntu" },
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
        config.set_environment_variables["prompt"] =
            "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
        config.set_environment_variables["DIRCMD"] = "/d"
        config.default_prog = { "cmd.exe", "/s", "/k", initBat }
    end

    if shellType == ShellTypes.PowerShell then
        config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" }
    end

    if shellType == ShellTypes.WSL then
        config.default_domain = "WSL:Ubuntu"
        config.default_prog = { "wsl.exe", "-d", "Ubuntu" }
        config.wsl_domains = {
            {
                name = "WSL:Ubuntu",
                distribution = "Ubuntu",
                default_cwd = "~",
            },
        }
    end
end

-- unbind alt enter
config.keys = {
    { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "u", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "d", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    -- emoji??
    { key = "u", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
}

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
    -- Helper to check if current pane is in a WSL domain
    local function is_wsl_pane(pane)
        local domain_name = pane:get_domain_name()
        print("is_wsl_pane: " .. tostring(domain_name))
        return domain_name and domain_name:find("WSL") ~= nil
    end

    -- Debug overlay (non-leader key, add to config.keys)
    table.insert(config.keys, { key = "L", mods = "CTRL", action = wezterm.action.ShowDebugOverlay })

    -- Conditional Ctrl+Space: WSL pane passes to tmux, others activate leader key table
    table.insert(config.keys, {
        key = " ",
        mods = "CTRL",
        action = wezterm.action_callback(function(window, pane)
            if is_wsl_pane(pane) then
                -- WSL pane: pass Ctrl+Space through to tmux
                window:perform_action(act.SendKey({ key = " ", mods = "CTRL" }), pane)
            else
                -- Non-WSL pane: activate wezterm leader key table
                window:perform_action(
                    act.ActivateKeyTable({
                        name = "leader",
                        one_shot = true,
                        timeout_milliseconds = 1000,
                    }),
                    pane
                )
            end
        end),
    })

    local function split_current_pane(direction)
        return wezterm.action_callback(function(window, pane)
            local cwd = pane:get_current_working_dir()
            local command = {
                domain = "CurrentPaneDomain",
            }

            if cwd then
                command.cwd = cwd
            end

            window:perform_action(
                act.SplitPane({
                    direction = direction,
                    command = command,
                }),
                pane
            )
        end)
    end

    -- Define leader key table with all leader bindings
    config.key_tables = {
        leader = {
            -- Escape to cancel leader mode
            { key = "Escape", action = act.PopKeyTable },
            -- Launcher
            { key = "T", mods = "SHIFT", action = act.ShowLauncher },
            -- Split horizontal
            { key = "|", mods = "SHIFT", action = split_current_pane("Right") },
            { key = "v", action = split_current_pane("Right") },
            -- Split vertical
            { key = "-", mods = "SHIFT", action = split_current_pane("Down") },
            { key = "s", action = split_current_pane("Down") },
            -- Switch to new or existing workspace
            {
                key = "W",
                mods = "SHIFT",
                action = act.PromptInputLine({
                    description = wezterm.format({
                        { Attribute = { Intensity = "Bold" } },
                        { Foreground = { AnsiColor = "Fuchsia" } },
                        { Text = "Enter name for new workspace." },
                    }),
                    action = wezterm.action_callback(function(window, pane, line)
                        if line then
                            window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
                        end
                    end),
                }),
            },
            { key = "s", mods = "SHIFT", action = act.ShowLauncherArgs({ flags = "WORKSPACES" }) },
            -- Pane/Tab management
            { key = "x", action = act.CloseCurrentPane({ confirm = true }) },
            { key = "&", mods = "SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
            {
                key = ",",
                action = act.PromptInputLine({
                    description = "Enter new name for tab",
                    action = wezterm.action_callback(function(window, pane, line)
                        if line then
                            window:active_tab():set_title(line)
                        end
                    end),
                }),
            },
            -- Tab navigation
            { key = "t", action = act.SpawnTab("CurrentPaneDomain") },
            { key = "p", action = act.ActivateTabRelative(-1) },
            { key = "n", action = act.ActivateTabRelative(1) },
        },
    }

    -- Tab switching keys 1-9
    for i = 1, 9 do
        table.insert(config.key_tables.leader, {
            key = tostring(i),
            action = act.ActivateTab(i - 1),
        })
    end

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

    tabline.setup({
        options = {
            icons_enabled = true,
            theme = "Catppuccin Frappe",
            tabs_enabled = true,
            theme_overrides = {},
            section_separators = {
                left = wezterm.nerdfonts.pl_left_hard_divider,
                right = wezterm.nerdfonts.pl_right_hard_divider,
            },
            component_separators = {
                left = wezterm.nerdfonts.pl_left_soft_divider,
                right = wezterm.nerdfonts.pl_right_soft_divider,
            },
            tab_separators = {
                left = wezterm.nerdfonts.pl_left_hard_divider,
                right = wezterm.nerdfonts.pl_right_hard_divider,
            },
        },
        sections = {
            tabline_a = { "mode" },
            tabline_b = { "workspace" },
            tabline_c = { "" },
            tab_active = {
                "index",
                { "parent", padding = 0 },
                "/",
                { "cwd", padding = { left = 0, right = 1 } },
                { "zoomed", padding = 0 },
            },
            tab_inactive = { "index", { "process", padding = { left = 0, right = 1 } } },
            tabline_x = { "ram", "cpu" },
            tabline_y = { "datetime", "battery" },
            tabline_z = { "domain" },
        },
        extensions = {},
    })
end

-- local font_family = "JetBrains Mono" -- or JetBrainsMono Nerd Font, Fira Code
local font = wezterm.font_with_fallback({
    "JetBrains Mono",
    "JetBrainsMono Nerd Font",
    "Fira Code Nerd Font",
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

return config
