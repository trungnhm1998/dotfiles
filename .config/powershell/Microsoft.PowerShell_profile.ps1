# ── Non-interactive / CI / agent guard ──────────────────────────────────────
# Skip the entire interactive profile (PSReadLine Vi-mode, starship, module
# imports, command overrides like ssh/ls/cd) unless this is a real interactive
# REPL. Agents and CI that spawn `pwsh -Command …`, `-File …`, or `-NonInteractive`
# then get vanilla PowerShell — no Vi-mode hang, no shadowed commands, no OSC
# noise — even when they forget -NoProfile. [Console]::IsInputRedirected alone
# misses conpty-based agents, so we inspect the launch args and CI env instead.
#
# psmux (native-Windows tmux) launches its pane shell with `-NoProfile -NoExit
# -Command <shim>`, and the shim manually dot-sources $PROFILE. That -Command
# would false-trip the arg scan and bail — but a session that stays open carries
# -NoExit (psmux panes do; one-shot agent/CI/tool-call `-Command …` invocations
# don't), so -NoExit exempts the arg scan. CI/GHA and non-ConsoleHost still bail.
$__args = [Environment]::GetCommandLineArgs()
$__oneShot = ($__args -notcontains '-NoExit') -and
($__args -match '^-(NonInteractive|Command|c|EncodedCommand|e|ec|File|f)$')
if ($env:CI -or $env:GITHUB_ACTIONS -or ($Host.Name -ne 'ConsoleHost') -or $__oneShot)
{
    return
}

$env:_ZO_DATA_DIR = "$HOME\ZoxideData"
$env:EDITOR = "nvim" # so can I press V and open nvim to edit commands
$env:VISUAL = "nvim"
$env:CLAUDE_CODE_TMUX_TRUECOLOR=1
# Starship logs "[WARN] Executing command git timed out" straight into the terminal when
# git_status blows command_timeout in a big repo -- that's the "prompt failed to render" garbage.
$env:STARSHIP_LOG = "error"

# Module imports. posh-git (git prompt) + Terminal-Icons (dir icons) removed 2026-07-04:
# redundant with Starship (prompt) + eza --icons, and they cost ~740ms/shell. CompletionPredictor
# removed 2026-07-11 (fed HistoryAndPlugin prediction; PredictionSource is History -- dead 26ms).
# PSReadLine import removed too: the interactive host loads the newest installed version itself.
# PSFzf (~225ms) + choco completion (~120ms) now load lazily at first idle -- see OnIdle block below.

$env:FZF_DEFAULT_OPTS="--height 50% --layout reverse --border top --inline-info --color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 --color=selected-bg:#51576D --color=border:#737994,label:#C6D0F5"


# Yazi
function y
{
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path)
    {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}

# --- eza / ls colors (Catppuccin Frappe) ---
# vivid output is static per vivid version -- cache it (spawning vivid cost ~160ms/shell);
# regenerated when vivid.exe is newer than the cache.
$__vivid = (Get-Command vivid -ErrorAction SilentlyContinue).Source
if ($__vivid)
{
    $__vividCache = "$env:LOCALAPPDATA\vivid-frappe.ls_colors"
    if (-not (Test-Path $__vividCache) -or (Get-Item $__vividCache).LastWriteTime -lt (Get-Item $__vivid).LastWriteTime)
    {
        vivid generate catppuccin-frappe | Set-Content $__vividCache -NoNewline
    }
    $env:LS_COLORS = Get-Content $__vividCache -Raw
} else
{
    # vivid not installed (e.g. Windows) — curated static Frappe EZA_COLORS
    $env:EZA_COLORS = "di=1;38;2;140;170;238:ex=1;38;2;166;209;137:ln=38;2;129;200;190:fi=38;2;198;208;245:da=38;2;131;139;167:uu=38;2;229;200;144:gu=38;2;131;139;167:ur=38;2;229;200;144:uw=38;2;231;130;132:ux=38;2;166;209;137:ue=38;2;166;209;137:gr=38;2;229;200;144:gw=38;2;231;130;132:gx=38;2;166;209;137:tr=38;2;229;200;144:tw=38;2;231;130;132:tx=38;2;166;209;137:sn=38;2;202;158;230:sb=38;2;202;158;230:xx=38;2;131;139;167"
}

# --- eza ---
function ls
{ eza --icons $args 
}
function l
{ eza --icons $args 
}
function ll
{ eza -lg --icons $args 
}
function la
{ eza -lag --icons $args 
}
function lt
{ eza -lTg --icons $args 
}
function lt1
{ eza -lTg --level=1 --icons $args 
}
function lt2
{ eza -lTg --level=2 --icons $args 
}
function lt3
{ eza -lTg --level=3 --icons $args 
}
function lta
{ eza -lTag --icons $args 
}
function lta1
{ eza -lTag --level=1 --icons $args 
}
function lta2
{ eza -lTag --level=2 --icons $args 
}
function lta3
{ eza -lTag --level=3 --icons $args 
}

# starship/zoxide init scripts are static per binary version -- cache to files and dot-source
# (saves the init process spawns, ~230ms/shell; starship's iex stub even spawned it twice).
# Regenerated when the exe is newer than the cache.
function __Update-InitCache([string]$Cache, [string]$ExePath, [string[]]$InitArgs)
{
    if (-not (Test-Path $Cache) -or (Get-Item $Cache).LastWriteTime -lt (Get-Item $ExePath).LastWriteTime)
    {
        & $ExePath @InitArgs | Set-Content $Cache
    }
}
$__starshipInit = "$env:LOCALAPPDATA\starship-init.ps1"
__Update-InitCache $__starshipInit (Get-Command starship).Source @('init', 'powershell', '--print-full-init')
. $__starshipInit
# integrate with wezterm because I use starship
$prompt = ""
function Invoke-Starship-PreCommand
{
    $current_location = $executionContext.SessionState.Path.CurrentLocation
    if ($current_location.Provider.Name -eq "FileSystem")
    {
        $ansi_escape = [char]27
        $provider_path = $current_location.ProviderPath -replace "\\", "/"
        $prompt = "$ansi_escape]7;file://${env:COMPUTERNAME}/${provider_path}$ansi_escape\"
    }
    $host.ui.Write($prompt)
}

# Publish this pane's WezTerm SERVER pane id as a user var so wezterm.lua's Claude tab-badge
# poller can map mux client<->server pane ids. Under the persistent unix mux the GUI is a client
# and renumbers panes, so $WEZTERM_PANE (server id, used in the alert filename) != the gui id the
# poller sees -- which silently broke the badge. Same SetUserVar OSC as `zj` below; value is base64.
if ($env:WEZTERM_PANE)
{
    $paneB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($env:WEZTERM_PANE))
    [Console]::Write("`e]1337;SetUserVar=CLAUDE_SERVER_PANE=$paneB64`a")
}

# =============================================================================
#
# Utility functions for zoxide.
#

# --cmd cd replaces `cd` with zoxide (and adds `cdi` for interactive jumps),
# mirroring the zsh setup (`zoxide init zsh --cmd cd`). Real `cd` paths/.. still
# work; only unknown args fall through to the zoxide database. No alias hack needed.
$__zoxideInit = "$env:LOCALAPPDATA\zoxide-init.ps1"
__Update-InitCache $__zoxideInit (Get-Command zoxide).Source @('init', 'powershell', '--cmd', 'cd')
. $__zoxideInit

Set-PSReadLineKeyHandler -Key Tab -Function Complete
if (-not [Console]::IsInputRedirected)
{
    Set-PSReadLineOption -EditMode vi -ViModeIndicator Cursor -PredictionSource History -PredictionViewStyle InlineView
}

# Catppuccin Frappe syntax colors (Mauve = accent; see docs/catppuccin-frappe-theme.md)
Set-PSReadLineOption -Colors @{
    Command          = '#8caaee'  # blue
    Comment          = '#838ba7'  # overlay1
    Keyword          = '#ca9ee6'  # mauve (accent)
    String           = '#a6d189'  # green
    Operator         = '#81c8be'  # teal
    Variable         = '#eebebe'  # flamingo
    Number           = '#ef9f76'  # peach
    Type             = '#e5c890'  # yellow
    Parameter        = '#ca9ee6'  # mauve (accent)
    Member           = '#c6d0f5'  # text
    Default          = '#c6d0f5'  # text
    Error            = '#e78284'  # red
    Selection        = '#414559'  # surface0
    InlinePrediction = '#626880'  # surface2
}

function claude-mem
{ & "bun" "C:\Users\mint\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" $args 
}

# Lazy-load the heavy extras at first idle -- fires right after the first prompt paints,
# so ctrl+f/ctrl+r and choco tab-completion are live within ~1s but don't block startup
# (PSFzf ~225ms + choco ~120ms). -Global: the event action runs in its own module scope.
$null = Register-EngineEvent PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module PSFzf -Global # Install-Module -Name PSFzf -Scope CurrentUser -Force
    Set-PsFzfOption -PSReadlineChordProvider "ctrl+f" -PSReadlineChordReverseHistory "ctrl+r"
    $choco = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path $choco)
    {
        Import-Module $choco -Global
    }
}

# --- Grammar fixer ---
function fix-grammar
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string] $PipeInput,
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $TextArgs
    )
    begin
    { $buf = [System.Collections.Generic.List[string]]::new() 
    }
    process
    { if ($PipeInput)
        { $buf.Add($PipeInput) 
        } 
    }
    end
    {
        $script = "$HOME\dotfiles\scripts\fix-grammar.ps1"
        if ($buf.Count -gt 0)
        {
            ($buf -join "`n") | & $script
        } elseif ($TextArgs.Count -gt 0)
        {
            & $script @TextArgs
        } else
        {
            & $script
        }
    }
}
Set-Alias -Name fg -Value fix-grammar

# OPENSPEC:START - OpenSpec completion (managed block, do not edit manually)
. "C:\Users\mint\Documents\PowerShell\OpenSpecCompletion.ps1"
# OPENSPEC:END

# --- Zellij ---
# Launch Zellij and flag the WezTerm pane (user var) so wezterm.lua stops emulating tmux
# while Zellij is the active multiplexer (see is_zellij_pane in wezterm.lua). MQ==/MA== are
# base64 for "1"/"0"; the flag clears on exit so the pane returns to WezTerm's leader.
function zj
{
    [Console]::Write("`e]1337;SetUserVar=zellij=MQ==`a")
    try
    { zellij @args 
    } finally
    { [Console]::Write("`e]1337;SetUserVar=zellij=MA==`a") 
    }
}

# --- ssh / wsl -> WezTerm mux passthrough ---
# Tell wezterm.lua which multiplexer owns Ctrl+Space when we shell out to ssh/wsl from a pwsh pane.
# The persistent `unix` mux hides child processes from pane:get_foreground_process_name() (it
# returns nil), so wezterm can't see that ssh/wsl is running -- we announce it via a user var, the
# same OSC 1337 SetUserVar mechanism as `zj` above. Cleared on exit (finally) so the pane returns
# to WezTerm's own leader. Read by mux_detect.pane_prog() in wezterm_mux_detect.lua.
function Set-WezVar([string]$Name, [string]$Value)
{
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
    [Console]::Write("`e]1337;SetUserVar=$Name=$b64`a")
}
function ssh
{
    Set-WezVar 'mux_prog' 'ssh'
    try
    { ssh.exe @args 
    } finally
    { Set-WezVar 'mux_prog' '' 
    }
}
function wsl
{
    Set-WezVar 'mux_prog' 'wsl'
    try
    { wsl.exe @args 
    } finally
    { Set-WezVar 'mux_prog' '' 
    }
}

# --- psmux (native-Windows tmux): flag the pane so wezterm.lua yields Ctrl+Space ---
# Same OSC-1337 user-var dance as zj/ssh/wsl above. Manual launch only -- no auto-attach.
function Invoke-Psmux
{
    Set-WezVar 'mux_prog' 'psmux'
    try
    { psmux.exe @args 
    } finally
    { Set-WezVar 'mux_prog' '' 
    }
}
Set-Alias psmux Invoke-Psmux
Set-Alias tmux  Invoke-Psmux   # muscle memory: `tmux` launches psmux + flags the pane
Set-Alias pmux  Invoke-Psmux

# --- Tablet-as-monitor toggle (SuperDisplay + SudoMaker) ---
# Both are indirect-display drivers (IDDs): a virtual ADAPTER owns the virtual display's
# lifecycle. An ACTIVE virtual display stalls WezTerm's GPU present path (DXGI occlusion ->
# no repaint until you click/right-click; a new window works, the old one stays stuck) -- even
# though the IDD monitor is GPU-attached to the RTX (same adapter as the real panel), not a
# separate virtual GPU. The lever is the ADAPTER: SuperDisplay also has a service to stop;
# SudoMaker is adapter-only, and a disabled PnP adapter stays disabled across reboots (durable,
# no StartType dance). Self-elevate (one UAC click); the virtual display (dis)appearing is the
# confirmation. See vault: WezTerm Repaint Stall from a Virtual Display on Windows.
function tablet-off
{
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',
    "Stop-Service SuperDisplay -EA SilentlyContinue; Get-PnpDevice -Class Display | Where-Object FriendlyName -match 'SuperDisplay|SudoMaker' | Disable-PnpDevice -Confirm:`$false -EA SilentlyContinue"
}
function tablet-on
{
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',
    "Get-PnpDevice -Class Display | Where-Object FriendlyName -match 'SuperDisplay|SudoMaker' | Enable-PnpDevice -Confirm:`$false -EA SilentlyContinue; Start-Service SuperDisplay -EA SilentlyContinue"
}

# --- gaming/work profile (see .config/profile/profile-toggle.ps1) ---
function game
{
    param([switch]$Reboot, [switch]$NoHypervisor)
    $toggleArgs = @('-Gaming')
    if ($Reboot)       { $toggleArgs += '-Reboot' }
    if ($NoHypervisor) { $toggleArgs += '-NoHypervisor' }   # FACEIT/ESEA lane; NOT for Valorant
    & (Join-Path $HOME '.config\profile\profile-toggle.ps1') @toggleArgs
}
function work
{
    param([switch]$Reboot)
    $toggleArgs = @('-Work')
    if ($Reboot) { $toggleArgs += '-Reboot' }
    & (Join-Path $HOME '.config\profile\profile-toggle.ps1') @toggleArgs
}

# Snapshot WezTerm's redraw-freeze state to a log -- run THIS the instant the screen stops
# repainting (it won't redraw until you mouse over it). Records Responding/renderer/injected-hook
# DLLs to ~/.cache/wezterm-freeze-probe.log. The real stall cause was an injected RTSS present-hook;
# see vault: WezTerm Repaint Stall from an Injected Overlay Hook on Windows.
function wz-probe
{ pwsh -NoProfile -ExecutionPolicy Bypass -File "$HOME\.config\wezterm\wezterm-freeze-probe.ps1" 
}

# --- Un-hide a Unity Editor window launched hidden by Unity Hub ---
# Unity Hub (Electron/Node) spawns Unity.exe with windowsHide=true -> STARTF_USESHOWWINDOW +
# wShowWindow=SW_HIDE; Unity's main window obeys it via ShowWindow(SW_SHOWDEFAULT) -> born hidden
# (no taskbar / alt-tab, .NET MainWindowHandle=0, but Responding=True). This shows it, no kill.
# Proven via PEB read; see vault: Recovering a Hidden Windows Window.
function Show-UnityWindow
{ & "$HOME\Show-UnityWindow.ps1" @args 
}
Set-Alias suw Show-UnityWindow

# --- Ad-hoc MCP servers (rare-use, not registered globally/per-project) ---
# Configs live in dotfiles\claude\mcp\<name>.json; `ccmcp figma jira` starts Claude with
# those servers for this session only. Leading args naming a config are consumed as
# servers; everything after passes to claude (e.g. `ccmcp figma -p "hi"`).
function ccmcp
{
    $mcpDir = "$HOME\dotfiles\claude\mcp"
    $cfgs = @(); $rest = @($args)
    while ($rest.Count -and (Test-Path "$mcpDir\$($rest[0]).json"))
    {
        $cfgs += "$mcpDir\$($rest[0]).json"
        $rest = @($rest | Select-Object -Skip 1)
    }
    if (-not $cfgs.Count)
    {
        Write-Error "No MCP config matched. Available: $((Get-ChildItem $mcpDir -Filter *.json).BaseName -join ', ')"
        return
    }
    claude --mcp-config @cfgs @rest
}

# --- Cursor global rules -> clipboard (Cursor has no global file to symlink) ---
# Cursor's User Rules live in a synced settings DB, so claude\AGENTS.md can't be symlinked
# in. Copy it to the clipboard, then paste into Cursor -> Settings -> Rules -> User Rules.
# Windows twin of scripts/copy-agents-rules.sh. Re-run after editing AGENTS.md.
function Copy-AgentsRules
{
    Get-Content "$HOME\.claude\AGENTS.md" -Raw | Set-Clipboard
    Write-Host "Copied AGENTS.md -> paste into Cursor -> Settings -> Rules -> User Rules."
}
Set-Alias ccrules Copy-AgentsRules

# --- Claude Code through better-ccflare (localhost:8080) for this one launch ---
# Plain `claude` talks to Anthropic directly (no User-level ANTHROPIC_BASE_URL anymore); `cc`
# opts this launch into the ccflare analytics proxy, then restores the shell's previous value.
# Note: Remote Control refuses non-api.anthropic.com endpoints, so use plain `claude` for /rc.
# Note: permission auto-mode's safety classifier (claude-opus-4-8[1m]) also routes through the
# proxy; when the 2-account pool is rate-limited it reports "temporarily unavailable".
function cc
{
    $saved = $env:ANTHROPIC_BASE_URL
    $env:ANTHROPIC_BASE_URL = "http://localhost:8080"
    try
    { claude @args
    } finally
    { if ($null -ne $saved)
        { $env:ANTHROPIC_BASE_URL = $saved
        } else
        { Remove-Item Env:\ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
        }
    }
}

# --- Claude Code against a local llama-swap/llama-server box (no auth, per-invocation) ---
# Points Claude Code at the OpenAI/Anthropic-compatible local server. Env is scoped to this
# shell only (no setx / global), so plain `claude` in other shells is unaffected.
function claude-local {
    param($Box = "http://127.0.0.1:8080", $Model = "fast")
    $env:ANTHROPIC_BASE_URL = $Box
    $env:ANTHROPIC_AUTH_TOKEN = "none"
    $env:ANTHROPIC_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
    claude @args
}

# Shortcuts: pin the whole CC session to one local chat model. fast<->big swap on the GPU, so it's
# one model per session (mixing them would thrash big's ~16s reload). Both params named so extra
# args (`cc-big --resume`) pass through to claude instead of hijacking the positional $Box.
function cc-fast { claude-local -Box 'http://127.0.0.1:8080' -Model fast @args }
function cc-big  { claude-local -Box 'http://127.0.0.1:8080' -Model big  @args }

# --- Obsidian vault sync task toggle ---
# ObsidianVaultSync (schtasks, runs scripts/vault-sync.ps1 every 30min) on/off/status.
function vault-sync {
    param([ValidateSet('on', 'off', 'status')] $do = 'status')
    switch ($do) {
        'on' { schtasks /Change /TN "ObsidianVaultSync" /ENABLE }
        'off' { schtasks /Change /TN "ObsidianVaultSync" /DISABLE }
        'status' { (schtasks /Query /TN "ObsidianVaultSync" /V /FO LIST | Select-String '^(Status|Scheduled Task State):') }
    }
}

# --- Local AI stack toggle (opt-in so the GPU stays free for gaming by default) ---
# `ai on`   start llama-swap (loopback 8080) -> Continue autocomplete + claude-local/opencode go live.
# `ai off`  stop llama-swap + any llama-server child -> frees ALL VRAM for games.
# `ai`      status: running? which models loaded? VRAM used.
# No logon autostart by design: nothing touches the GPU until you opt in with `ai on`.
function ai {
    param([ValidateSet('on', 'off', 'status')] $do = 'status')
    $exe = 'H:\llm\llama-swap\llama-swap.exe'
    $cfg = "$HOME\dotfiles\.config\llama-swap\config.yaml"
    if (-not (Test-Path $exe)) { Write-Host 'local AI stack not installed on this machine' -ForegroundColor DarkGray; return }
    switch ($do) {
        'on' {
            if (Get-Process llama-swap -ErrorAction SilentlyContinue) { Write-Host 'llama-swap already on' -ForegroundColor Yellow; break }
            Start-Process $exe -ArgumentList '--config', $cfg, '--listen', '127.0.0.1:8080' -WindowStyle Hidden -RedirectStandardOutput H:\llm\swap-out.log -RedirectStandardError H:\llm\swap-err.log
            Write-Host 'llama-swap ON  (127.0.0.1:8080) - autocomplete + local agents live' -ForegroundColor Green
        }
        'off' {
            Get-Process llama-swap, llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
            Write-Host 'local AI OFF - VRAM freed for gaming' -ForegroundColor Green
        }
        'status' {
            if (Get-Process llama-swap -ErrorAction SilentlyContinue) {
                $m = try { (Invoke-RestMethod http://127.0.0.1:8080/running -TimeoutSec 2).running.model -join ', ' } catch { '' }
                Write-Host ("llama-swap ON  | loaded: {0}" -f $(if ($m) { $m } else { '(none yet)' })) -ForegroundColor Green
            } else {
                Write-Host 'llama-swap off' -ForegroundColor DarkGray
            }
            Write-Host ("VRAM used: " + (nvidia-smi --query-gpu=memory.used --format=csv,noheader))
        }
    }
}
