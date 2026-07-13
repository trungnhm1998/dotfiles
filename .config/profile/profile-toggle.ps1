#Requires -Version 5.1
<#
    profile-toggle.ps1 — flip the machine between WORK and GAMING profiles.
    Design: docs/specs/2026-07-13-gaming-profile-design.md
      (no args)        -> toggle (marker says work -> go gaming, and vice versa)
      -Gaming | -Work  -> switch explicitly (idempotent)
      -Boot            -> replay marker profile at logon (staggered starts)
      -State           -> print bar glyph (yasb pill poll)
      -Reboot          -> with -Gaming: write marker then reboot clean
      -NoHypervisor    -> with -Gaming -Reboot: also bcdedit hypervisor off (FACEIT/ESEA lane)
#>
param(
    [switch]$Gaming,
    [switch]$Work,
    [switch]$Boot,
    [switch]$State,
    [switch]$Reboot,
    [switch]$NoHypervisor
)

$MarkerDir   = Join-Path $HOME '.config\dotfiles'
$MarkerPath  = Join-Path $MarkerDir 'profile'
$RequestPath = Join-Path $MarkerDir 'profile-elevated-request'
$LogPath     = Join-Path $env:TEMP 'profile-toggle.log'

# --- App table: THE single source of truth -----------------------------------
# Profile='work'   : killed going gaming, started going work.
# Profile='gaming' : killed going work,  started going gaming.
# KillOrder/StartOrder: ascending; fast/input-critical first on kill, Docker last
# (slow graceful stop) and first on start (slowest to warm up).
$Apps = @(
    @{ Name='kanata';    Profile='work'; KillOrder=10; StartOrder=20; Custom=@{ Kill={ }; Start={ } } }
    @{ Name='komorebi';  Profile='work'; KillOrder=11; StartOrder=21; Custom=@{ Kill={ }; Start={ } } }
    @{ Name='PowerToys'; Profile='work'; Procs=@('PowerToys*')
       Start=(Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe') }
    @{ Name='Slack';     Profile='work'; Procs=@('slack')
       Start=(Join-Path $env:LOCALAPPDATA 'slack\slack.exe'); StartArgs=@('--startup') }
    @{ Name='GoogleDrive'; Profile='work'; Procs=@('GoogleDriveFS')
       Start=(Join-Path $env:ProgramFiles 'Google\Drive File Stream\launch.bat') }
    @{ Name='PhoneLink'; Profile='work'; Procs=@('PhoneExperienceHost','CrossDeviceService','CrossDeviceResume')
       Start=$null; Custom=@{ Kill={ }; Start={ } } }   # kill-only: Windows relaunches it on demand
    @{ Name='KDEConnect'; Profile='work'; Procs=@('kdeconnectd','kdeconnect-indicator')
       Start=(Join-Path $env:ProgramFiles 'KDE Connect\bin\kdeconnect-indicator.exe') }
    @{ Name='Deskflow';  Profile='work'; Procs=@('deskflow','deskflow-core','deskflow-daemon')
       Start=(Join-Path $env:ProgramFiles 'Deskflow\deskflow.exe') }
    @{ Name='Tailscale'; Profile='work'; KillOrder=60; StartOrder=60; Custom=@{ Kill={ }; Start={ } } }
    @{ Name='OpenVPN';   Profile='work'; KillOrder=61; StartOrder=61; Custom=@{ Kill={ }; Start={ } } }
    @{ Name='Docker';    Profile='work'; KillOrder=90; StartOrder=10; StartDelaySec=5
       Custom=@{ Kill={ }; Start={ } } }
    @{ Name='Steam';     Profile='gaming'; Procs=@('steam')
       Start=(Join-Path ${env:ProgramFiles(x86)} 'Steam\steam.exe'); StartArgs=@('-silent') }
    @{ Name='ExitLag';   Profile='gaming'; Procs=@('ExitLag')
       Start=(Join-Path $env:ProgramFiles 'ExitLag\ExitLag.exe') }
    @{ Name='Discord';   Profile='gaming'; Procs=@('Discord')
       Start=(Join-Path $env:LOCALAPPDATA 'Discord\Update.exe')
       StartArgs=@('--processStart','Discord.exe') }
)

function Get-ProfileActions {
    # Pure: direction -> ordered kill/start sets. No process probing here (testable).
    param([Parameter(Mandatory)][ValidateSet('gaming','work')][string]$Direction)
    $kill  = @($Apps | Where-Object { $_.Profile -ne $Direction } |
        Sort-Object { if ($_.ContainsKey('KillOrder'))  { $_.KillOrder }  else { 50 } })
    $start = @($Apps | Where-Object { $_.Profile -eq $Direction } |
        Sort-Object { if ($_.ContainsKey('StartOrder')) { $_.StartOrder } else { 50 } })
    return @{ Kill = $kill; Start = $start }
}

function ConvertTo-ProfileName {
    # Pure: marker file contents -> profile name. Anything but 'gaming' is work (safe default).
    param([string]$Raw)
    if ($Raw -and $Raw.Trim() -eq 'gaming') { return 'gaming' }
    return 'work'
}

function Get-ProfileMarker {
    $raw = ''
    if (Test-Path $MarkerPath) {
        try { $raw = Get-Content -Path $MarkerPath -Raw -ErrorAction Stop } catch { $raw = '' }
    }
    return ConvertTo-ProfileName -Raw $raw
}

function Set-ProfileMarker {
    param([Parameter(Mandatory)][string]$Value)
    if (-not (Test-Path $MarkerDir)) { New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null }
    Set-Content -Path $MarkerPath -Value $Value -NoNewline
}

function Write-ProfileLog {
    param([Parameter(Mandatory)][string]$Message)
    "$(Get-Date -Format s)  $Message" | Add-Content -Path $LogPath
}

function Write-ProfileState {
    # Raw UTF-8 bytes straight to stdout so the PUA glyph survives yasb's redirected
    # pipe (same reason as wm-toggle.ps1). work = U+F0B1 (briefcase)  gaming = U+F11B (gamepad).
    $glyph = if ((Get-ProfileMarker) -eq 'gaming') { [char]0xF11B } else { [char]0xF0B1 }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($glyph)
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}

# Run only when executed directly; dot-sourcing (Pester) just loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    if ($State) { Write-ProfileState }
    # other verbs land in Task 2
}
