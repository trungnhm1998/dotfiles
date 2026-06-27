--- @type Wezterm
local wezterm = require("wezterm")

local vim_smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
-- Fuzzy workspace + zoxide switcher. Upstream is archived but works on current WezTerm;
-- if it ever breaks on an update, migrate to a fork or mikkasendke/sessionizer.wezterm.
-- Requires zoxide on PATH (present: scoop shim). This also makes the "smart_workspace_switcher"
-- tabline extension below live instead of dormant.
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_macos = (wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin")
    or false

-- Repaint cap: match the 240 Hz monitor (144 on a 240 Hz panel judders; WT paints at refresh).
-- animation_fps only drives cursor-blink/visual-bell easing — 60 is smooth and saves idle GPU.
config.max_fps = 240
config.animation_fps = 60
local launch_menu = {}

config.color_scheme = "Catppuccin Frappe"
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_and_split_indices_are_zero_based = false
config.set_environment_variables = {}
-- WebGpu (modern GPU path) handles synchronized output / frame coalescing better than
-- the legacy OpenGL path, which is a known TUI-flicker offender. If WebGpu misbehaves on
-- Windows (rare crash/flicker on Dx12), revert to "OpenGL" or try "Software".
-- See wiki: [[Claude Code TUI Rendering on Windows]].
config.front_end = "WebGpu"
-- wgpu defaults to webgpu_power_preference = "LowPower", which on this desktop selects the
-- Intel UHD 770 iGPU instead of the RTX 5070 Ti and tanks bulk-output throughput ~10x
-- (12.3 MB `type`: 70.5 s vs 7.1 s, benched 2026-06-10; on the right GPU WezTerm == WT).
-- NOTE: do NOT pin webgpu_preferred_adapter via wezterm.gui.enumerate_gpus() here — config
-- eval runs many times at startup/reload and each enumerate pays a full multi-backend GPU
-- scan (measured: startup 0.6 s -> 6+ s). If WebGpu misbehaves again, fall back to "OpenGL"
-- (benched equal to Windows Terminal on this machine).
config.webgpu_power_preference = "HighPerformance"
config.notification_handling = "AlwaysShow"
config.tab_max_width = 100
config.term = "xterm-256color"
-- Nightly channel is updated by update-everything.ps1; skip the startup update check.
config.check_for_updates = false

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
    -- Shift+Enter -> newline. WezTerm sends a bare CR for Shift+Enter by default
    -- (indistinguishable from Enter, so apps just submit). Re-emit Alt+Enter (ESC+CR),
    -- which Claude Code / readline-style multiline inputs treat as "insert newline" --
    -- the same sequence Option+Enter already produces once its default fullscreen bind
    -- is disabled above. SendKey goes straight to the pane (no keybinding recursion).
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendKey({ key = "Enter", mods = "ALT" }) },
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
        return domain_name and domain_name:find("WSL") ~= nil
    end

    -- A pane is "Zellij-driven" when the zj wrapper set the user var (see PowerShell profile).
    local function is_zellij_pane(pane)
        local ok, vars = pcall(function() return pane:get_user_vars() end)
        return ok and vars and vars.zellij == "1"
    end

    -- A local pane is "SSH'd out" when its foreground process is an ssh/mosh client. WezTerm
    -- can't see the REMOTE process, but the local ssh.exe IS the most-recent descendant of the
    -- pwsh pane, so this detects "I'm in an SSH session" and hands Ctrl+Space to the remote
    -- tmux instead of grabbing it for WezTerm's leader. Heuristic + has overhead, but only runs
    -- on a Ctrl+Space press. See https://wezterm.org/config/lua/pane/get_foreground_process_name.html
    local function is_ssh_pane(pane)
        local ok, name = pcall(function() return pane:get_foreground_process_name() end)
        if not ok or not name then return false end
        name = (name:gsub("\\", "/"):match("[^/]+$") or name):lower() -- basename
        return name == "ssh.exe" or name == "ssh" or name == "mosh.exe" or name == "mosh"
            or name == "mosh-client.exe"
    end

    -- Debug overlay / Lua REPL now lives in leader_mode below on `:` (tmux/vim
    -- command-prompt parallel); the old global Ctrl+Shift+L binding is removed.

    -- Conditional Ctrl+Space: WSL pane or SSH'd-out pane passes to the remote tmux, others
    -- activate the leader key table.
    table.insert(config.keys, {
        key = " ",
        mods = "CTRL",
        action = wezterm.action_callback(function(window, pane)
            -- if is_wsl_pane(pane) or is_zellij_pane(pane) then
            if is_wsl_pane(pane) or is_ssh_pane(pane) then
                -- WSL pane / ssh out (e.g. ssh to the Mac) -> the remote tmux owns Ctrl+Space, so
                -- pass it through (not into leader_mode) instead of letting WezTerm's leader hijack it.
                window:perform_action(act.SendKey({ key = " ", mods = "CTRL" }), pane)
            else
                -- Native pwsh pane: activate wezterm leader key table (tmux emulation).
                -- No timeout: tmux's prefix waits indefinitely for the next key.
                -- prevent_fallback: an unbound key is swallowed, not sent to the shell
                -- (tmux cancel-and-discard). one_shot: exit after a single command key,
                -- which also means the prevent_fallback lock-out risk can't apply here.
                window:perform_action(
                    act.ActivateKeyTable({
                        name = "leader_mode",
                        one_shot = true,
                        prevent_fallback = true,
                    }),
                    pane
                )
            end
        end),
    })

    -- Lockout backstop: clear the whole key-table stack from anywhere. Ctrl+Shift+Esc is
    -- NOT usable (Windows reserves it for Task Manager), so use Ctrl+Shift+Space.
    table.insert(config.keys, {
        key = " ",
        mods = "CTRL|SHIFT",
        action = act.ClearKeyTableStack,
    })

    -- Build a SpawnCommand for actions launched from the current pane: keep the
    -- same domain and relaunch pwsh for local panes. Deliberately do NOT set `cwd`:
    -- a CurrentPaneDomain command already inherits the active pane's working
    -- directory, and WezTerm converts that URL to a native path correctly. Setting
    -- cwd ourselves from get_current_working_dir().file_path breaks on Windows --
    -- it returns a "/C:/..." path WezTerm rejects (os error 123), silently falling
    -- back to the home directory.
    local function pane_command(pane)
        local command = { domain = "CurrentPaneDomain" }
        if pane:get_domain_name() == "local" then
            command.args = { pwsh, "-NoLogo" }
        end
        return command
    end

    local function split_current_pane(direction)
        return wezterm.action_callback(function(window, pane)
            window:perform_action(
                act.SplitPane({ direction = direction, command = pane_command(pane) }),
                pane
            )
        end)
    end

    -- Reconcile module for the Claude tab-badge alert dir (pure logic, unit-tested in
    -- claude/hooks/tests/test-claude-alerts.lua).
    local claude_alerts = require('wezterm_claude_alerts')
    local claude_focus = require('wezterm_claude_focus')

    -- Track the previously-active workspace so Leader+L can jump back (tmux `prefix + L`).
    -- update-status fires ~1x/sec and on switch, so it captures every switch path (relative
    -- cycle, w-prompt, launcher, fuzzy switcher) without wrapping them. Multiple update-status
    -- handlers all run, so this is additive alongside tabline's own.
    wezterm.on("update-status", function(window)
        local current = window:active_workspace()
        if wezterm.GLOBAL.current_workspace ~= current then
            -- GLOBAL is purpose-built to hold arbitrary cross-reload state; LuaLS types it
            -- as opaque userdata, so silence its inject-field nag on these two writes.
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.previous_workspace = wezterm.GLOBAL.current_workspace
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.current_workspace = current
        end

        -- Claude tab badge: reconcile THIS mux's alert subdir into GLOBAL.claude_alert. The dir
        -- is namespaced per WezTerm mux (basename of WEZTERM_UNIX_SOCKET) so multiple windows --
        -- separate muxes with colliding pane-id spaces -- don't prune each other's files over the
        -- shared dir. Sole writer of that table; prunes this mux's dead panes, clears visited tab.
        local dir = claude_alerts.mux_dir(wezterm.home_dir, os.getenv('XDG_CACHE_HOME'), os.getenv('WEZTERM_UNIX_SOCKET'))
        local paths = {}
        pcall(function() paths = wezterm.read_dir(dir) end)   -- missing dir -> {}
        local live = {}
        for _, w in ipairs(wezterm.mux.all_windows()) do
            for _, t in ipairs(w:tabs()) do
                for _, p in ipairs(t:panes()) do
                    live[tostring(p:pane_id())] = true
                end
            end
        end
        local visited = {}
        local at = window:active_tab()
        if at then
            for _, p in ipairs(at:panes()) do
                visited[tostring(p:pane_id())] = true
            end
        end
        local function read_file(path)
            local fh = io.open(path, 'r'); if not fh then return nil end
            local s = fh:read('*a'); fh:close(); return s
        end
        ---@diagnostic disable-next-line: inject-field
        wezterm.GLOBAL.claude_alert = claude_alerts.reconcile(paths, live, visited, read_file, os.remove)

        -- Focus-on-click: a clicked toast dropped a one-shot marker for one of THIS mux's
        -- panes (claude-notify.ps1 activate-mode). Find it, switch workspace if needed,
        -- activate the pane (tab + pane), and raise the OS window — the only reliable
        -- cross-window raise on Windows (wezterm cli cannot). Side effects run only when a
        -- request is pending, so ordinary ticks are unaffected.
        local fdir = claude_focus.mux_dir(wezterm.home_dir, os.getenv('XDG_CACHE_HOME'), os.getenv('WEZTERM_UNIX_SOCKET'))
        local fpaths = {}
        pcall(function() fpaths = wezterm.read_dir(fdir) end)
        local want = claude_focus.pending(fpaths, os.time(), read_file, os.remove, 60)
        if #want > 0 then
            local want_set = {}
            for _, id in ipairs(want) do want_set[id] = true end
            for _, gw in ipairs(wezterm.gui.gui_windows()) do
                local mw = gw:mux_window()
                for _, tab in ipairs(mw:tabs()) do
                    for _, p in ipairs(tab:panes()) do
                        if want_set[tostring(p:pane_id())] then
                            local target_ws = mw:get_workspace()
                            if target_ws and target_ws ~= gw:active_workspace() then
                                pcall(function() wezterm.mux.set_active_workspace(target_ws) end)
                            end
                            pcall(function() p:activate() end)   -- tab + pane
                            pcall(function() gw:focus() end)     -- raise the OS window
                        end
                    end
                end
            end
        end
    end)

    -- Define leader key table with all leader bindings
    config.key_tables = {
        leader_mode = {
            -- tmux: prefix Escape -> copy mode (your `bind Escape copy-mode`; `[` is unbound).
            -- Cancel-leader is intentionally gone: press any unbound key (swallowed) to exit,
            -- or use the Ctrl+Shift+Space backstop.
            { key = "Escape", action = act.ActivateCopyMode },
            -- tmux: send-prefix. Ideally this would be Ctrl+Space Ctrl+Space, but a MODIFIED
            -- key can't match inside a custom key table on Windows WezTerm (see WezTerm #6824),
            -- so the literal Ctrl+Space (NUL) is sent via prefix then plain Space instead.
            { key = " ", action = act.SendKey({ key = " ", mods = "CTRL" }) },
            -- tmux: prefix ] -> paste (your `bind ] paste-buffer`).
            { key = "]", action = act.PasteFrom("Clipboard") },
            -- tmux: prefix hjkl -> select pane (your `bind hjkl select-pane`).
            { key = "h", action = act.ActivatePaneDirection("Left") },
            { key = "j", action = act.ActivatePaneDirection("Down") },
            { key = "k", action = act.ActivatePaneDirection("Up") },
            { key = "l", action = act.ActivatePaneDirection("Right") },
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
            -- Fuzzy workspace launcher (built-in): type to filter existing workspaces
            { key = "s", mods = "SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
            -- Fuzzy switcher (smart_workspace_switcher): existing workspaces + zoxide dirs in one keypress
            { key = "f", action = workspace_switcher.switch_workspace() },
            -- Fast cycle (tmux-style): ( prev workspace, ) next workspace, L last-used (toggle)
            { key = "(", mods = "SHIFT", action = act.SwitchWorkspaceRelative(-1) },
            { key = ")", mods = "SHIFT", action = act.SwitchWorkspaceRelative(1) },
            {
                key = "L",
                mods = "SHIFT",
                action = wezterm.action_callback(function(window, pane)
                    local prev = wezterm.GLOBAL.previous_workspace
                    if not prev then
                        return
                    end
                    -- A renamed/closed workspace leaves `prev` stale; switching to a name the
                    -- mux no longer knows would silently spawn an empty workspace. Guard it.
                    for _, name in ipairs(wezterm.mux.get_workspace_names()) do
                        if name == prev then
                            window:perform_action(act.SwitchToWorkspace({ name = prev }), pane)
                            return
                        end
                    end
                end),
            },
            -- Rename the active workspace (tmux `prefix + $`)
            {
                key = "$",
                mods = "SHIFT",
                action = act.PromptInputLine({
                    description = "Rename workspace to:",
                    action = wezterm.action_callback(function(_, _, line)
                        if line and line ~= "" then
                            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
                        end
                    end),
                }),
            },
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
                    window:perform_action(act.SpawnCommandInNewTab(pane_command(pane)), pane)
                end),
            },
            { key = "p", action = act.ActivateTabRelative(-1) },
            { key = "n", action = act.ActivateTabRelative(1) },
            -- Zoom pane toggle (mimics tmux prefix + z)
            { key = "z", action = act.TogglePaneZoomState },
            -- Debug overlay / Lua REPL (tmux `prefix :` + vim `:` command-prompt parallel)
            { key = ":", mods = "SHIFT", action = act.ShowDebugOverlay },
            -- tmux-style sticky resize (parallels `bind -r ... resize-pane`). Entered with
            -- plain `r`: arrows/hjkl repeat without re-pressing prefix; Esc/q exit. The
            -- prefix-r reload bind was dropped — WezTerm auto-reloads on save, so it was
            -- redundant. A MODIFIED entry key (Shift+R, Ctrl+r) can NOT be used: modifiers
            -- don't match inside a custom key table on Windows WezTerm (WezTerm #6824).
            -- Gated on pane count: a single-pane tab has nothing to resize, so `r` is a
            -- no-op there (tmux resize-pane behaves the same) and we don't enter the mode.
            -- leader_mode is one_shot, so the no-op path simply exits the prefix.
            {
                key = "r",
                action = wezterm.action_callback(function(window, pane)
                    local tab = window:active_tab()
                    if tab and #tab:panes() > 1 then
                        window:perform_action(
                            act.ActivateKeyTable({ name = "resize_mode", one_shot = false }),
                            pane
                        )
                    end
                end),
            },
        },
        -- Sticky resize: one_shot=false keeps it active across repeats; Esc/q exit.
        resize_mode = {
            { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
            { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
            { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
            { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
            { key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 1 }) },
            { key = "DownArrow", action = act.AdjustPaneSize({ "Down", 1 }) },
            { key = "UpArrow", action = act.AdjustPaneSize({ "Up", 1 }) },
            { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 1 }) },
            { key = "Escape", action = act.PopKeyTable },
            { key = "q", action = act.PopKeyTable },
        },
    }

    -- Tab switching keys 1-9
    for i = 1, 9 do
        table.insert(config.key_tables.leader_mode, {
            key = tostring(i),
            action = act.ActivateTab(i - 1),
        })
    end

    -- tmux copy-mode-vi parity. WezTerm's default copy_mode is already vi-style (hjkl,
    -- v/V/Ctrl+v select, y -> ClipboardAndPrimarySelection then exit, / search, g/G,
    -- Ctrl+u/Ctrl+d, q/Esc exit) — which matches the user's `mode-keys vi` + tmux-yank. The
    -- only gap is Enter: tmux's `copy-mode-vi Enter send -X copy-selection-and-cancel`. Start
    -- from the defaults, drop any existing bare-Enter binding, then add copy-and-close.
    -- wezterm.gui is nil when the config is evaluated GUI-less (e.g. the mux server), where
    -- default_key_tables() would throw and abort the whole config. Guard it; copy mode still
    -- works from WezTerm's built-in defaults there, just without the Enter copy-and-exit tweak.
    if wezterm.gui then
        local copy_mode = wezterm.gui.default_key_tables().copy_mode
        local copy_mode_keys = {}
        for _, m in ipairs(copy_mode) do
            if not (m.key == "Enter" and (m.mods == nil or m.mods == "NONE")) then
                table.insert(copy_mode_keys, m)
            end
        end
        table.insert(copy_mode_keys, {
            key = "Enter",
            mods = "NONE",
            action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
        })
        config.key_tables.copy_mode = copy_mode_keys
    end

    -- Register our custom tab component under the name tabline.wez will require()
    -- for it. require() checks package.loaded first, so this avoids depending on
    -- nested path resolution into the plugin's namespace.
    package.loaded['tabline.components.tab.claude'] = require('tabline_claude_badge')

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
                        elseif mode == "RESIZE" then
                            -- Sticky resize mode (leader -> r). Four-way arrows = adjust
                            -- a pane edge in any of h/j/k/l directions. NOTE: a mode shown
                            -- here MUST also have a matching theme section in set_theme
                            -- below, or tabline's update-status indexes a nil theme and
                            -- the whole bar freezes on its last paint (see resize_mode there).
                            icon = wezterm.nerdfonts.md_arrow_all
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
                "claude", -- Claude bell badge: precise alert, else unseen-output fallback;
                          -- also runs clear-on-visit for the active tab (see note above)
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
    -- tabline's default theme only ships normal_mode / copy_mode / search_mode (see the
    -- plugin's config.lua get_colors). Every custom key_table whose name ends in `_mode`
    -- is surfaced by the mode component, and component.lua indexes config.theme[<mode>]
    -- WITHOUT a nil guard — so a mode lacking a section here throws inside update-status
    -- and freezes the whole status bar on its previous paint. leader_mode and resize_mode
    -- below are REQUIRED for that reason, not just cosmetics.
    tabline.set_theme({
        -- Leader prefix: catppuccin frappe pink (ansi[6] #f4b8e4).
        leader_mode = {
            a = { fg = background, bg = colors.ansi[6] },
            b = { fg = colors.ansi[6], bg = surface },
            c = { fg = colors.foreground, bg = background },
        },
        -- Sticky resize: catppuccin frappe teal (ansi[7] #81c8be) — distinct from the
        -- pink leader so the LEADER -> RESIZE transition is unmistakable in the bar.
        resize_mode = {
            a = { fg = background, bg = colors.ansi[7] },
            b = { fg = colors.ansi[7], bg = surface },
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
    -- log level to use: info, warn, error ("info" logs on every Ctrl+hjkl navigation)
    log_level = "warn",
})

-- Emoji fallback: WezTerm auto-appends its bundled Noto Color Emoji, but (a) that
-- makes emoji look different from Windows Terminal (Segoe), and (b) JetBrainsMono
-- Nerd Font ships MONOCHROME glyphs for many emoji-presentation codepoints
-- (✅ ✨ ℹ ⏺ …) that shadow the color fallback. Listing the platform color-emoji
-- font with assume_emoji_presentation routes those codepoints to color and matches
-- Windows Terminal. Verify with: wezterm ls-fonts --text "✅✨ℹ️⏺🎉"
-- See wiki: [[Claude Code TUI Rendering on Windows]].
local font_fallback = {
    "JetBrainsMono Nerd Font",
    "JetBrains Mono",
}
if is_windows then
    table.insert(font_fallback, { family = "Segoe UI Emoji", assume_emoji_presentation = true })
elseif is_macos then
    table.insert(font_fallback, { family = "Apple Color Emoji", assume_emoji_presentation = true })
end
local font = wezterm.font_with_fallback(font_fallback)
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
