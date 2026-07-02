$env:_ZO_DATA_DIR = "$HOME\ZoxideData"
$env:EDITOR = "nvim" # so can I press V and open nvim to edit commands
$env:VISUAL = "nvim"

# https://github.com/janikvonrotz/awesome-powershell
Import-Module posh-git # Install-Module posh-git -Scope CurrentUser -Force
# Terminal-Icons rewrites its theme cache (%APPDATA%\powershell\Community\Terminal-Icons\*.xml) on
# every import via non-atomic Export-Clixml -Force. Concurrent pwsh launches (psmux / Zellij / Claude
# agent-team panes) can read a file mid-rewrite -> corrupt CliXml -> the module's UNGUARDED load-time
# Import-CliXml throws and the whole import aborts with a wall of red. The on-disk file self-heals once
# the writing shell finishes, so one retry usually wins; degrade quietly if the race is still open.
# ponytail: retry-once, not a write-lock -- a heavy concurrent storm can still skip icons this session.
# Install-Module -Name Terminal-Icons -Repository PSGallery
try {
    Import-Module Terminal-Icons -ErrorAction Stop
} catch {
    try { Import-Module Terminal-Icons -ErrorAction Stop }
    catch { Write-Verbose "Terminal-Icons skipped (concurrent-launch race): $($_.Exception.Message)" }
}
Import-Module PSReadLine # Install-Module PSReadLine -Repository PSGallery -Scope CurrentUser -AllowPrerelease -Force
Import-Module CompletionPredictor # Install-Module CompletionPredictor -Scope CurrentUser
Import-Module PSFzf # Install-Module -Name PSFzf -Scope CurrentUser -Forcef

$env:FZF_DEFAULT_OPTS="--height 50% --layout reverse --border top --inline-info --color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 --color=selected-bg:#51576D --color=border:#737994,label:#C6D0F5"


# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Yazi
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}

# --- eza / ls colors (Catppuccin Frappe) ---
if (Get-Command vivid -ErrorAction SilentlyContinue) {
    $env:LS_COLORS = (vivid generate catppuccin-frappe)
} else {
    # vivid not installed (e.g. Windows) — curated static Frappe EZA_COLORS
    $env:EZA_COLORS = "di=1;38;2;140;170;238:ex=1;38;2;166;209;137:ln=38;2;129;200;190:fi=38;2;198;208;245:da=38;2;131;139;167:uu=38;2;229;200;144:gu=38;2;131;139;167:ur=38;2;229;200;144:uw=38;2;231;130;132:ux=38;2;166;209;137:ue=38;2;166;209;137:gr=38;2;229;200;144:gw=38;2;231;130;132:gx=38;2;166;209;137:tr=38;2;229;200;144:tw=38;2;231;130;132:tx=38;2;166;209;137:sn=38;2;202;158;230:sb=38;2;202;158;230:xx=38;2;131;139;167"
}

# --- eza ---
function ls { eza --icons $args }
function l { eza --icons $args }
function ll { eza -lg --icons $args }
function la { eza -lag --icons $args }
function lt { eza -lTg --icons $args }
function lt1 { eza -lTg --level=1 --icons $args }
function lt2 { eza -lTg --level=2 --icons $args }
function lt3 { eza -lTg --level=3 --icons $args }
function lta { eza -lTag --icons $args }
function lta1 { eza -lTag --level=1 --icons $args }
function lta2 { eza -lTag --level=2 --icons $args }
function lta3 { eza -lTag --level=3 --icons $args }

Invoke-Expression (&starship init powershell)
# integrate with wezterm because I use starship
$prompt = ""
function Invoke-Starship-PreCommand {
    $current_location = $executionContext.SessionState.Path.CurrentLocation
    if ($current_location.Provider.Name -eq "FileSystem") {
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
if ($env:WEZTERM_PANE) {
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
Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })

Set-PSReadLineKeyHandler -Key Tab -Function Complete
if (-not [Console]::IsInputRedirected) {
    Set-PSReadLineOption -EditMode vi -ViModeIndicator Cursor -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
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

function claude-mem { & "bun" "C:\Users\mint\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" $args }

# Ovrride vi mode ctrl r
Set-PsFzfOption -PSReadlineChordProvider "ctrl+f"
Set-PsFzfOption -PSReadlineChordReverseHistory "ctrl+r"

# --- Grammar fixer ---
function fix-grammar {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string] $PipeInput,
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $TextArgs
    )
    begin   { $buf = [System.Collections.Generic.List[string]]::new() }
    process { if ($PipeInput) { $buf.Add($PipeInput) } }
    end {
        $script = "$HOME\dotfiles\scripts\fix-grammar.ps1"
        if ($buf.Count -gt 0) {
            ($buf -join "`n") | & $script
        } elseif ($TextArgs.Count -gt 0) {
            & $script @TextArgs
        } else {
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
function zj {
    [Console]::Write("`e]1337;SetUserVar=zellij=MQ==`a")
    try { zellij @args } finally { [Console]::Write("`e]1337;SetUserVar=zellij=MA==`a") }
}

# --- ssh / wsl -> WezTerm mux passthrough ---
# Tell wezterm.lua which multiplexer owns Ctrl+Space when we shell out to ssh/wsl from a pwsh pane.
# The persistent `unix` mux hides child processes from pane:get_foreground_process_name() (it
# returns nil), so wezterm can't see that ssh/wsl is running -- we announce it via a user var, the
# same OSC 1337 SetUserVar mechanism as `zj` above. Cleared on exit (finally) so the pane returns
# to WezTerm's own leader. Read by mux_detect.pane_prog() in wezterm_mux_detect.lua.
function Set-WezVar([string]$Name, [string]$Value) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
    [Console]::Write("`e]1337;SetUserVar=$Name=$b64`a")
}
function ssh {
    Set-WezVar 'mux_prog' 'ssh'
    try { ssh.exe @args } finally { Set-WezVar 'mux_prog' '' }
}
function wsl {
    Set-WezVar 'mux_prog' 'wsl'
    try { wsl.exe @args } finally { Set-WezVar 'mux_prog' '' }
}

# --- psmux (native-Windows tmux): flag the pane so wezterm.lua yields Ctrl+Space ---
# Same OSC-1337 user-var dance as zj/ssh/wsl above. Manual launch only -- no auto-attach.
function Invoke-Psmux {
    Set-WezVar 'mux_prog' 'psmux'
    try { psmux.exe @args } finally { Set-WezVar 'mux_prog' '' }
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
function tablet-off {
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',
      "Stop-Service SuperDisplay -EA SilentlyContinue; Get-PnpDevice -Class Display | Where-Object FriendlyName -match 'SuperDisplay|SudoMaker' | Disable-PnpDevice -Confirm:`$false -EA SilentlyContinue"
}
function tablet-on {
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',
      "Get-PnpDevice -Class Display | Where-Object FriendlyName -match 'SuperDisplay|SudoMaker' | Enable-PnpDevice -Confirm:`$false -EA SilentlyContinue; Start-Service SuperDisplay -EA SilentlyContinue"
}

# Snapshot WezTerm's redraw-freeze state to a log -- run THIS the instant the screen stops
# repainting (it won't redraw until you mouse over it). Records Responding/renderer/injected-hook
# DLLs to ~/.cache/wezterm-freeze-probe.log. The real stall cause was an injected RTSS present-hook;
# see vault: WezTerm Repaint Stall from an Injected Overlay Hook on Windows.
function wz-probe { pwsh -NoProfile -ExecutionPolicy Bypass -File "$HOME\.config\wezterm\wezterm-freeze-probe.ps1" }

# --- Un-hide a Unity Editor window launched hidden by Unity Hub ---
# Unity Hub (Electron/Node) spawns Unity.exe with windowsHide=true -> STARTF_USESHOWWINDOW +
# wShowWindow=SW_HIDE; Unity's main window obeys it via ShowWindow(SW_SHOWDEFAULT) -> born hidden
# (no taskbar / alt-tab, .NET MainWindowHandle=0, but Responding=True). This shows it, no kill.
# Proven via PEB read; see vault: Recovering a Hidden Windows Window.
function Show-UnityWindow { & "$HOME\Show-UnityWindow.ps1" @args }
Set-Alias suw Show-UnityWindow

# --- Ad-hoc MCP servers (rare-use, not registered globally/per-project) ---
# Configs live in dotfiles\claude\mcp\<name>.json; `ccmcp figma jira` starts Claude with
# those servers for this session only. Leading args naming a config are consumed as
# servers; everything after passes to claude (e.g. `ccmcp figma -p "hi"`).
function ccmcp {
  $mcpDir = "$HOME\dotfiles\claude\mcp"
  $cfgs = @(); $rest = @($args)
  while ($rest.Count -and (Test-Path "$mcpDir\$($rest[0]).json")) {
    $cfgs += "$mcpDir\$($rest[0]).json"
    $rest = @($rest | Select-Object -Skip 1)
  }
  if (-not $cfgs.Count) {
    Write-Error "No MCP config matched. Available: $((Get-ChildItem $mcpDir -Filter *.json).BaseName -join ', ')"
    return
  }
  claude --mcp-config @cfgs @rest
}
