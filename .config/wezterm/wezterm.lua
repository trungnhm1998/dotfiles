--- @type Wezterm
local wezterm = require("wezterm")

local vim_smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_macos = (wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin")
    or false

-- max fps
config.max_fps = 144
config.animation_fps = 144
local launch_menu = {}

config.color_scheme = "Catppuccin Frappe"
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_and_split_indices_are_zero_based = false
config.set_environment_variables = {}
config.front_end = "OpenGL"
config.notification_handling = "AlwaysShow"
config.tab_max_width = 100
config.term = "xterm-256color"

local ShellTypes = {
    NONE = 0,
    CMD = 1,
    CMDER = 2,
    PowerShell = 3,
    WSL = 4,
}

local shellType = ShellTypes.PowerShell

-- WSL Configuration: Set your default distro here
local WSL_DEFAULT_DISTRO = "Ubuntu-24.04"

-- Function to detect installed WSL distributions
local function get_wsl_distros()
    local distros = {}
    local success, output, stderr = wezterm.run_child_process({ "wsl.exe", "-l", "--quiet" })

    if not success then
        wezterm.log_warn("Failed to detect WSL distros: " .. (stderr or "unknown error"))
        return distros
    end

    -- WSL outputs in UTF-16LE with spaces between characters
    -- Parse the output line by line
    for line in output:gmatch("[^\r\n]+") do
        -- Remove null bytes and extra spaces from UTF-16LE encoding
        local distro_name = line:gsub("%z", ""):gsub("^%s+", ""):gsub("%s+$", "")

        -- Check if this is the default distro (marked with *)
        local is_default = false
        if distro_name:match("^%*") then
            is_default = true
            distro_name = distro_name:gsub("^%*%s*", "")
        end

        -- Only add non-empty distro names
        if distro_name ~= "" then
            table.insert(distros, {
                name = distro_name,
                is_default = is_default,
            })
        end
    end

    return distros
end

-- Detect PowerShell 7 path dynamically
local pwsh_paths = {
    "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
    "C:\\Program Files\\PowerShell\\pwsh.exe",
}
local pwsh = pwsh_paths[1] -- default
for _, path in ipairs(pwsh_paths) do
    local f = io.open(path, "r")
    if f then
        f:close()
        pwsh = path
        break
    end
end

if is_windows then
    -- Detect available WSL distros
    local wsl_distros = get_wsl_distros()
    local default_distro = WSL_DEFAULT_DISTRO
    local default_wsl_domain = "WSL:" .. default_distro

    -- Validate that the default distro exists in detected distros
    if #wsl_distros > 0 then
        local found_default = false
        for _, distro_info in ipairs(wsl_distros) do
            if distro_info.name == default_distro then
                found_default = true
                break
            end
        end
        if not found_default then
            wezterm.log_warn(
                "Default distro '"
                    .. default_distro
                    .. "' not found in detected WSL distros. Using first available: "
                    .. wsl_distros[1].name
            )
            default_distro = wsl_distros[1].name
            default_wsl_domain = "WSL:" .. default_distro
        end
    end

    -- PowerShell 7
    table.insert(launch_menu, {
        label = "PowerShell 7",
        args = { pwsh, "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- PowerShell 7
    table.insert(launch_menu, {
        label = "PowerShell 7 no profile",
        args = { pwsh, "--noprofile" },
        domain = { DomainName = "local" },
    })

    -- Windows PowerShell (5.1)
    table.insert(launch_menu, {
        label = "Windows PowerShell",
        args = { "powershell.exe", "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- Add all detected WSL distros to launcher menu
    for _, distro_info in ipairs(wsl_distros) do
        local distro_name = distro_info.name
        local wsl_domain = "WSL:" .. distro_name
        local label = "WSL: " .. distro_name

        -- Mark the configured default distro
        if distro_name == default_distro then
            label = label .. " (default)"
        end

        -- Also mark WSL's system default with an asterisk
        if distro_info.is_default then
            label = label .. " *"
        end

        table.insert(launch_menu, {
            label = label,
            domain = { DomainName = wsl_domain },
        })
    end

    -- Cmder (use environment variable or fallback to default path)
    local cmder_root = os.getenv("cmder_root") or os.getenv("CMDER_ROOT") or "C:\\tools\\cmder"
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
        config.default_prog = { pwsh, "-NoLogo" }
    end

    if shellType == ShellTypes.WSL then
        config.default_domain = default_wsl_domain
        config.default_prog = { "wsl.exe", "-d", default_distro }

        -- Set up wsl_domains for all detected distros
        config.wsl_domains = {}
        for _, distro_info in ipairs(wsl_distros) do
            table.insert(config.wsl_domains, {
                name = "WSL:" .. distro_info.name,
                distribution = distro_info.name,
                default_cwd = "~",
            })
        end
    end
end

-- unbind alt enter
config.keys = {
    { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "u", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "d", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    -- emoji??
    { key = "u", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
    { key = "n", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
}

if is_windows then
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
                        name = "leader_mode",
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
            local command = { domain = "CurrentPaneDomain" }

            if pane:get_domain_name() == "local" then
                command.args = { pwsh, "-NoLogo" }
            end

            local cwd = pane:get_current_working_dir()
            if cwd then
                command.cwd = cwd
            end

            window:perform_action(act.SplitPane({ direction = direction, command = command }), pane)
        end)
    end

    -- Define leader key table with all leader bindings
    config.key_tables = {
        leader_mode = {
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
                key = "w",
                action = act.PromptInputLine({
                    description = wezterm.format({
                        { Attribute = { Underline = "Double" } },
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
            {
                key = "t",
                action = wezterm.action_callback(function(window, pane)
                    local command = { domain = "CurrentPaneDomain" }
                    if pane:get_domain_name() == "local" then
                        command.args = { pwsh, "-NoLogo" }
                    end
                    window:perform_action(act.SpawnCommandInNewTab(command), pane)
                end),
            },
            { key = "p", action = act.ActivateTabRelative(-1) },
            { key = "n", action = act.ActivateTabRelative(1) },
            -- Zoom pane toggle (mimics tmux prefix + z)
            { key = "z", action = act.TogglePaneZoomState },
        },
    }

    -- Tab switching keys 1-9
    for i = 1, 9 do
        table.insert(config.key_tables.leader_mode, {
            key = tostring(i),
            action = act.ActivateTab(i - 1),
        })
    end

    tabline.setup({
        options = {
            icons_enabled = true,
            theme = "Catppuccin Frappe",
            tabs_enabled = true,
            section_separators = {
                left = "",
                right = "",
            },
            component_separators = {
                left = "",
                right = "",
            },
            tab_separators = {
                left = "",
                right = "",
            },
            right = "",
        },
        sections = {
            tabline_a = {
                {
                    "mode",
                    --- format call back
                    --- I'm going for "icon mode" eg. " LEADER"
                    --- if we want icon only then it would be "icon"
                    --- but if the keys table doesn't have to mode
                    --- fallback to "mode" event if you has icon for it
                    --- icon at https://wezterm.org/config/lua/wezterm/nerdfonts.html
                    --- or https://www.nerdfonts.com/cheat-sheet
                    ---@param mode any
                    ---@param window Window
                    ---@return string
                    fmt = function(mode, window)
                        local icon_only = true
                        local icon = nil

                        if mode == "LEADER" then
                            icon = wezterm.nerdfonts.md_keyboard_outline
                        elseif mode == "NORMAL" then
                            icon = wezterm.nerdfonts.cod_terminal
                        elseif mode == "COPY" then
                            icon = wezterm.nerdfonts.md_scissors_cutting
                        elseif mode == "SEARCH" then
                            icon = wezterm.nerdfonts.oct_search
                        end

                        -- fallback
                        if icon_only and icon == nil then
                            return mode
                        end

                        -- adding space to icon then mode if support mode
                        return string.format(
                            "%s%s",
                            icon and icon .. (icon_only and "" or " ") or "",
                            icon_only and "" or mode
                        )
                    end,
                },
            },
            tabline_b = { "workspace" },
            tabline_c = { " " },
            tab_active = {
                "index",
                { "parent", padding = 0 },
                "/",
                { "cwd", padding = { left = 0, right = 1 } },
                { "zoomed", padding = 0 },
            },
            tab_inactive = {
                "index",
                -- { "output" },
                { "tab", padding = { left = 0, right = 1 } },
            },
            -- tabline_x = { "ram", "cpu" },
            tabline_x = {},
            tabline_y = { "datetime" },
            tabline_z = { "domain" },
        },
        extensions = {
            "resurrect",
            "smart_workspace_switcher",
            "quick_domains",
        },
    })

    local colors = tabline.get_theme().colors
    local surface = colors.cursor and colors.cursor.bg or colors.ansi[1]
    local background = colors.tab_bar and colors.tab_bar.inactive_tab and colors.tab_bar.inactive_tab.bg_color
        or colors.background
    tabline.set_theme({
        leader_mode = {
            a = { fg = background, bg = colors.ansi[6] },
            b = { fg = colors.ansi[6], bg = surface },
            c = { fg = colors.foreground, bg = background },
        },
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

local font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "JetBrains Mono",
})
local macbookFontSize = 13
local windowsFontSize = 10
config.font = font
config.font_size = is_macos and macbookFontSize or windowsFontSize

--ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
config.freetype_load_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
config.freetype_render_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'

config.inactive_pane_hsb = {
    brightness = 0.6,
}

config.launch_menu = launch_menu
return config
