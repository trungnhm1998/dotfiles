#Requires -Version 5.1
<#
    profile-toggle.ps1 — flip the machine between WORK and GAMING profiles.
    Design: docs/specs/2026-07-13-gaming-profile-design.md
      (no args)        -> toggle (marker says work -> go gaming, and vice versa)
      -Gaming | -Work  -> switch explicitly (idempotent)
      -Boot            -> replay marker profile at logon (staggered starts)
      -State           -> print bar glyph (yasb pill poll)
      -Reboot          -> with -Gaming/-Work: write marker then reboot clean
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
    @{ Name='kanata';    Profile='work'; KillOrder=10; StartOrder=20; Custom=@{
        # existing toggle is the owner; -Off is idempotent, plain call is a blind toggle
        Kill  = { & pwsh -NoProfile -File (Join-Path $HOME '.config\kanata\kanata-toggle.ps1') -Off }
        Start = { if (-not (Get-Process kanata* -ErrorAction SilentlyContinue)) {
                      & pwsh -NoProfile -File (Join-Path $HOME '.config\kanata\kanata-toggle.ps1') } }
    } }
    @{ Name='komorebi';  Profile='work'; KillOrder=11; StartOrder=21; Custom=@{
        # wm-toggle is a blind toggle -> gate each direction on komorebi's run state
        Kill  = { if (Get-Process komorebi -ErrorAction SilentlyContinue) {
                      & pwsh -NoProfile -File (Join-Path $HOME '.config\komorebi\wm-toggle.ps1') } }
        Start = { if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
                      & pwsh -NoProfile -File (Join-Path $HOME '.config\komorebi\wm-toggle.ps1') } }
    } }
    @{ Name='PowerToys'; Profile='work'; Procs=@('PowerToys*')
       Start=(Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe') }
    @{ Name='Slack';     Profile='work'; Procs=@('slack')
       Start=(Join-Path $env:LOCALAPPDATA 'slack\slack.exe'); StartArgs=@('--startup') }
    @{ Name='GoogleDrive'; Profile='work'; Procs=@('GoogleDriveFS')
       Start=(Join-Path $env:ProgramFiles 'Google\Drive File Stream\launch.bat') }
    @{ Name='PhoneLink'; Profile='work'; Procs=@('PhoneExperienceHost','CrossDeviceService','CrossDeviceResume'); Custom=@{
        Kill  = { foreach ($p in 'PhoneExperienceHost','CrossDeviceService','CrossDeviceResume') {
                      Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } }
        Start = { }   # kill-only: Windows relaunches Phone Link on demand
    } }
    @{ Name='KDEConnect'; Profile='work'; Procs=@('kdeconnectd','kdeconnect-indicator')
       Start=(Join-Path $env:ProgramFiles 'KDE Connect\bin\kdeconnect-indicator.exe') }
    @{ Name='Deskflow';  Profile='work'; Procs=@('deskflow','deskflow-core','deskflow-daemon')
       Start=(Join-Path $env:ProgramFiles 'Deskflow\deskflow.exe') }
    @{ Name='Tailscale'; Profile='work'; KillOrder=60; StartOrder=60; Custom=@{
        Kill  = { & (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe') down 2>$null
                  Get-Process tailscale-ipn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start = { if (-not (Get-Process tailscale-ipn -ErrorAction SilentlyContinue)) {
                      Start-Process (Join-Path $env:ProgramFiles 'Tailscale\tailscale-ipn.exe') }
                  & (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe') up 2>$null }
    } }
    @{ Name='OpenVPN';   Profile='work'; KillOrder=61; StartOrder=61; Custom=@{
        # GUI dies here; the agent services stop/start via the elevated task (batched in Invoke-ProfileSwitch)
        Kill  = { Get-Process OpenVPNConnect -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start = { if (-not (Get-Process OpenVPNConnect -ErrorAction SilentlyContinue)) {
                      Start-Process (Join-Path $env:ProgramFiles 'OpenVPN Connect\OpenVPNConnect.exe') `
                          -ArgumentList '--opened-at-login','--minimize' } }
    } }
    @{ Name='Docker';    Profile='work'; KillOrder=90; StartOrder=10; StartDelaySec=5; Custom=@{
        Kill  = {
            # 1. SIGTERM containers (DB-safe), 2. official desktop stop w/ timeout, 3. wsl --shutdown
            $ids = & docker ps -q 2>$null
            if ($ids) { & docker stop $ids 2>$null | Out-Null }
            $job = Start-Job { & docker desktop stop 2>$null }
            if (-not (Wait-Job $job -Timeout 60)) {
                # ponytail: 60s then force — docker desktop stop can hang on some WSL2 setups
                Get-Process 'Docker Desktop','com.docker*' -ErrorAction SilentlyContinue |
                    Stop-Process -Force -ErrorAction SilentlyContinue
            }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            & wsl --shutdown 2>$null
        }
        Start = {
            if (-not (Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue)) {
                Start-Process (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
            }
        }
    } }
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
    # File is the source of truth; echo to the console too so an interactive
    # `game`/`work` shows progress instead of sitting mute through the slow
    # Docker teardown (yasb/AHK callers discard stdout, so this is safe).
    param([Parameter(Mandatory)][string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    $line | Add-Content -Path $LogPath
    Write-Host $line
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

function Invoke-AppKill {
    param([Parameter(Mandatory)][hashtable]$App)
    if ($App.Custom) { & $App.Custom.Kill; return }
    foreach ($p in $App.Procs) {
        Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-AppStart {
    param([Parameter(Mandatory)][hashtable]$App)
    if ($App.Custom) { & $App.Custom.Start; return }
    $running = @($App.Procs | ForEach-Object { Get-Process $_ -ErrorAction SilentlyContinue } | Where-Object { $_ })
    if ($running.Count -gt 0) { return }                      # idempotent
    if (-not (Test-Path $App.Start)) { Write-ProfileLog "SKIP start $($App.Name): missing $($App.Start)"; return }
    if ($App.StartArgs) { Start-Process -FilePath $App.Start -ArgumentList $App.StartArgs }
    else                { Start-Process -FilePath $App.Start }
}

function Request-Elevated {
    # Drop a one-shot request file and poke the pre-registered elevated task (no UAC).
    # The elevated side validates + deletes the file; 60s TTL guards stale requests.
    param([Parameter(Mandatory)][string[]]$Lines)
    if (-not (Test-Path $MarkerDir)) { New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null }
    Set-Content -Path $RequestPath -Value $Lines
    schtasks /run /tn 'dotfiles-profile-elevated' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-ProfileLog 'WARN elevated task missing - service/bcdedit ops skipped (run deploy_windows.ps1)' }
}

function Invoke-ProfileSwitch {
    param(
        [Parameter(Mandatory)][ValidateSet('gaming','work')][string]$Direction,
        [switch]$WithHypervisorOff,
        [switch]$RebootAfter,
        [switch]$Stagger        # -Boot: pause between starts to avoid a logon CPU storm
    )
    $mutex = [System.Threading.Mutex]::new($false, 'Local\profile-toggle')
    if (-not $mutex.WaitOne(0)) { Write-ProfileLog 'debounced: another switch in progress'; return }
    try {
        Write-ProfileLog "-> $Direction begin"
        $plan = Get-ProfileActions -Direction $Direction
        foreach ($app in $plan.Kill) {
            try { Invoke-AppKill -App $app; Write-ProfileLog "killed $($app.Name)" }
            catch { Write-ProfileLog "ERROR kill $($app.Name): $($_.Exception.Message)" }
        }
        foreach ($app in $plan.Start) {
            try { Invoke-AppStart -App $app; Write-ProfileLog "started $($app.Name)" }
            catch { Write-ProfileLog "ERROR start $($app.Name): $($_.Exception.Message)" }
            if ($Stagger -and $app.StartDelaySec) { Start-Sleep -Seconds $app.StartDelaySec }
        }
        # Elevated batch: VPN services always; hypervisor only on the explicit lane.
        # work always sends hv=auto-if-off so a prior -NoHypervisor session self-heals.
        $lines = @()
        if ($Direction -eq 'gaming') {
            $lines += 'vpn=stop'
            if ($WithHypervisorOff) { $lines += 'hv=off' }
        } else {
            $lines += 'vpn=start'
            $lines += 'hv=auto-if-off'
        }
        Request-Elevated -Lines $lines
        Set-ProfileMarker -Value $Direction
        Write-ProfileLog "-> $Direction done"
        if ($RebootAfter) {
            # The elevated task (cold pwsh start + stopping 2 VPN services + bcdedit) can
            # lose the race against a fixed-delay reboot; wait for it to consume the
            # request file before shutting down, so hypervisor/VPN state isn't stale.
            $waitedSec = 0
            while ((Test-Path $RequestPath) -and ($waitedSec -lt 30)) {
                Start-Sleep -Seconds 1
                $waitedSec += 1
            }
            if (Test-Path $RequestPath) {
                Write-ProfileLog 'WARN elevated request not consumed after 30s; rebooting anyway'
            } else {
                Start-Sleep -Seconds 5   # grace period for the elevated actions to finish
                Write-ProfileLog "elevated request consumed after ${waitedSec}s; proceeding with reboot"
            }
            shutdown /r /t 5
        }
    } finally {
        $mutex.ReleaseMutex()
    }
}

# Run only when executed directly; dot-sourcing (Pester) just loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    if ($State) {
        Write-ProfileState
    } elseif ($Boot) {
        Invoke-ProfileSwitch -Direction (Get-ProfileMarker) -Stagger
    } elseif ($Gaming) {
        Invoke-ProfileSwitch -Direction 'gaming' -WithHypervisorOff:$NoHypervisor -RebootAfter:$Reboot
    } elseif ($Work) {
        Invoke-ProfileSwitch -Direction 'work' -RebootAfter:$Reboot
    } else {
        # bare call = toggle (yasb pill click)
        $next = if ((Get-ProfileMarker) -eq 'gaming') { 'work' } else { 'gaming' }
        Invoke-ProfileSwitch -Direction $next
    }
}
