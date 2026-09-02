#Requires -Version 7.0
<#
    profile-toggle.ps1 — flip the machine between WORK and GAMING profiles.
    Design: docs/specs/2026-07-13-gaming-profile-design.md
      (no args)        -> toggle (marker says work -> go gaming, and vice versa)
      -Gaming | -Work  -> switch explicitly (idempotent)
      -Boot            -> replay marker profile at logon (staggered starts)
      -State           -> print bar glyph (yasb pill poll)
      -Reboot          -> with -Gaming/-Work: write marker then reboot clean
      -Restore         -> put the machine back to the pre-game snapshot (game -Off / ungame)
#>
param(
    [switch]$Gaming,
    [switch]$Work,
    [switch]$Boot,
    [switch]$State,
    [switch]$Reboot,
    [switch]$Restore
)

$MarkerDir   = Join-Path $HOME '.config\dotfiles'
$MarkerPath  = Join-Path $MarkerDir 'profile'
$RequestPath = Join-Path $MarkerDir 'profile-elevated-request'
$LogPath     = Join-Path $env:TEMP 'profile-toggle.log'
$SnapshotPath = Join-Path $MarkerDir 'profile-snapshot.json'
# Must match $ManagedServices in profile-elevated.ps1 (the elevated side is the whitelist).
$ManagedServices = @('agent_ovpnconnect', 'ovpnhelper_service', 'DoSvc')

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
        Probe = { [bool](Get-Process kanata* -ErrorAction SilentlyContinue) }
    } }
    @{ Name='komorebi';  Profile='work'; KillOrder=11; StartOrder=21; Custom=@{
        # wm-toggle is a blind toggle -> gate each direction on komorebi's run state
        Kill  = { if (Get-Process komorebi -ErrorAction SilentlyContinue) {
                      & pwsh -NoProfile -File (Join-Path $HOME '.config\komorebi\wm-toggle.ps1') } }
        Start = { if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
                      & pwsh -NoProfile -File (Join-Path $HOME '.config\komorebi\wm-toggle.ps1') } }
        Probe = { [bool](Get-Process komorebi -ErrorAction SilentlyContinue) }
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
        Probe = { $false }
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
        Probe = { [bool](Get-Process tailscale-ipn -ErrorAction SilentlyContinue) }
    } }
    @{ Name='OpenVPN';   Profile='work'; KillOrder=61; StartOrder=61; Custom=@{
        # GUI dies here; the agent services stop/start via the elevated task (batched in Invoke-ProfileSwitch)
        Kill  = { Get-Process OpenVPNConnect -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start = { if (-not (Get-Process OpenVPNConnect -ErrorAction SilentlyContinue)) {
                      Start-Process (Join-Path $env:ProgramFiles 'OpenVPN Connect\OpenVPNConnect.exe') `
                          -ArgumentList '--opened-at-login','--minimize' } }
        Probe = { [bool](Get-Process OpenVPNConnect -ErrorAction SilentlyContinue) }
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
        Probe = { [bool](Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue) }
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

function Test-AppRunning {
    param([Parameter(Mandatory)][hashtable]$App)
    if ($App.Custom) { return [bool](& $App.Custom.Probe) }
    foreach ($p in $App.Procs) {
        if (Get-Process $p -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function New-ProfileSnapshot {
    # Pure: probe results -> snapshot. Only managed services are kept (whitelist).
    param(
        [Parameter(Mandatory)][hashtable]$AppStates,
        [Parameter(Mandatory)][hashtable]$ServiceStates,
        [Parameter(Mandatory)][string]$PowerScheme,
        [Parameter(Mandatory)][bool]$VirtualDisplaysEnabled,
        [Parameter(Mandatory)][string]$BootTime
    )
    $services = @{}
    foreach ($n in $ManagedServices) {
        if ($ServiceStates.ContainsKey($n)) { $services[$n] = $ServiceStates[$n] }
    }
    return [ordered]@{
        schemaVersion          = 1
        createdUtc             = (Get-Date).ToUniversalTime().ToString('o')
        bootTime               = $BootTime
        apps                   = $AppStates
        services               = $services
        powerScheme            = $PowerScheme
        virtualDisplaysEnabled = $VirtualDisplaysEnabled
        restore                = @{}
    }
}

function Get-MachineSnapshot {
    # Impure collector. Everything here is readable unelevated.
    # ponytail: local var is $appStates, not $apps -- PowerShell variable names are
    # case-insensitive, so $apps would shadow the script-scoped $Apps table below.
    $appStates = @{}
    foreach ($a in $Apps) { $appStates[$a.Name] = Test-AppRunning -App $a }
    $services = @{}
    foreach ($n in $ManagedServices) {
        $s = Get-Service $n -ErrorAction SilentlyContinue
        if ($s) { $services[$n] = [string]$s.Status }
    }
    $scheme = [regex]::Match(((powercfg /getactivescheme) -join ' '), '[0-9a-f-]{36}').Value
    # Read-only probe by friendly name (same match the pwsh profile's vdisp helper uses);
    # the elevated side still matches by hardware id before touching anything.
    $vdisp = [bool](Get-PnpDevice -Class Display -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'OK' -and $_.FriendlyName -match 'SudoMaker|SuperDisplay' })
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('o')
    return New-ProfileSnapshot -AppStates $appStates -ServiceStates $services -PowerScheme $scheme `
        -VirtualDisplaysEnabled $vdisp -BootTime $boot
}

function Save-ProfileSnapshot {
    param([Parameter(Mandatory)]$Snapshot)
    if (-not (Test-Path $MarkerDir)) { New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null }
    $Snapshot | ConvertTo-Json -Depth 4 | Set-Content -Path $SnapshotPath -Encoding UTF8
}

function Read-ProfileSnapshot {
    # $null when absent, unreadable, or a schema we do not know (caller falls back to work).
    if (-not (Test-Path $SnapshotPath)) { return $null }
    try { $snap = Get-Content -Path $SnapshotPath -Raw | ConvertFrom-Json -AsHashtable }
    catch { Write-ProfileLog "WARN snapshot unreadable: $($_.Exception.Message)"; return $null }
    if ($snap.schemaVersion -ne 1) { Write-ProfileLog "WARN snapshot schemaVersion $($snap.schemaVersion) unsupported"; return $null }
    return $snap
}

function Get-RestoreActions {
    # Pure: snapshot -> diff-based plan. Kill gaming apps that were down, start work
    # apps that were up, start services that were Running, re-enable vdisp if it was.
    param([Parameter(Mandatory)][hashtable]$Snapshot)
    $was = $Snapshot.apps
    $kill  = @($Apps | Where-Object { $_.Profile -eq 'gaming' -and -not $was[$_.Name] } |
        Sort-Object { if ($_.ContainsKey('KillOrder'))  { $_.KillOrder }  else { 50 } })
    $start = @($Apps | Where-Object { $_.Profile -eq 'work' -and $was[$_.Name] } |
        Sort-Object { if ($_.ContainsKey('StartOrder')) { $_.StartOrder } else { 50 } })
    $lines = @()
    if ($Snapshot.virtualDisplaysEnabled) { $lines += 'vdisp=on' }
    foreach ($n in $ManagedServices) {
        if ($Snapshot.services[$n] -eq 'Running') { $lines += "svc=$n=start" }
    }
    return @{ Kill = $kill; Start = $start; Elevated = $lines; PowerScheme = [string]$Snapshot.powerScheme }
}

function Get-EnterDecision {
    # Pure. snapshot + marker=gaming: already in a session. snapshot + marker=work:
    # a previous restore did not finish (or a crash) -> restore, then enter.
    param([Parameter(Mandatory)][bool]$SnapshotExists, [Parameter(Mandatory)][string]$Marker)
    if (-not $SnapshotExists) { return 'enter' }
    if ($Marker -eq 'gaming') { return 'noop' }
    return 'restore-then-enter'
}

function Invoke-ProfileRestore {
    $snap = Read-ProfileSnapshot
    if (-not $snap) {
        Write-ProfileLog 'no snapshot - falling back to the work profile'
        Invoke-ProfileSwitch -Direction 'work'
        return
    }
    $mutex = [System.Threading.Mutex]::new($false, 'Local\profile-toggle')
    if (-not $mutex.WaitOne(0)) { Write-ProfileLog 'debounced: another switch in progress'; return }
    try {
        Write-ProfileLog '-> restore begin'
        $plan   = Get-RestoreActions -Snapshot $snap
        $status = @{}
        # Reverse of apply: displays + services first (elevated), power, then processes
        # last because Docker and the VPN GUIs need their services.
        if ($plan.Elevated.Count) {
            $status['elevated'] = if (Request-Elevated -Lines $plan.Elevated) { 'ok' } else { 'skipped: no elevated task' }
        }
        if ($plan.PowerScheme) {
            powercfg /setactive $plan.PowerScheme | Out-Null
            $status['power'] = if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed: powercfg exit $LASTEXITCODE" }
        }
        foreach ($app in $plan.Kill) {
            try { Invoke-AppKill -App $app; $status["kill:$($app.Name)"] = 'ok'; Write-ProfileLog "killed $($app.Name)" }
            catch { $status["kill:$($app.Name)"] = "failed: $($_.Exception.Message)"; Write-ProfileLog "ERROR kill $($app.Name): $($_.Exception.Message)" }
        }
        foreach ($app in $plan.Start) {
            try { Invoke-AppStart -App $app; $status["start:$($app.Name)"] = 'ok'; Write-ProfileLog "started $($app.Name)" }
            catch { $status["start:$($app.Name)"] = "failed: $($_.Exception.Message)"; Write-ProfileLog "ERROR start $($app.Name): $($_.Exception.Message)" }
        }
        $snap.restore = $status
        Save-ProfileSnapshot -Snapshot $snap
        $failed = @($status.Values | Where-Object { $_ -like 'failed*' })
        if ($failed.Count -eq 0) {
            Remove-Item $SnapshotPath -Force -ErrorAction SilentlyContinue
            Write-ProfileLog '-> restore done, snapshot removed'
        } else {
            Write-ProfileLog "-> restore done with $($failed.Count) failure(s); snapshot kept, next 'game' retries"
        }
        Set-ProfileMarker -Value 'work'
    } finally {
        $mutex.ReleaseMutex()
    }
}

function Invoke-GamingEntry {
    param([switch]$RebootAfter)
    switch (Get-EnterDecision -SnapshotExists (Test-Path $SnapshotPath) -Marker (Get-ProfileMarker)) {
        'noop'               { Write-ProfileLog "already in a gaming session (snapshot present) - run 'ungame' first" }
        'restore-then-enter' { Write-ProfileLog 'stale snapshot with marker=work - restoring first'
                               Invoke-ProfileRestore
                               Invoke-ProfileSwitch -Direction 'gaming' -RebootAfter:$RebootAfter }
        'enter'              { Invoke-ProfileSwitch -Direction 'gaming' -RebootAfter:$RebootAfter }
    }
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
    if ($LASTEXITCODE -ne 0) {
        Write-ProfileLog 'WARN elevated task missing - service/vdisp ops skipped (run deploy_windows.ps1)'
        return $false
    }
    return $true
}

function Get-ElevatedRequestLines {
    # Elevated batch: managed services + virtual display adapters. The SudoMaker/
    # SuperDisplay adapters are phantom displays and needless surface for a kernel
    # anti-cheat. DoSvc: 24H2/25H2 RAM-growth bug and P2P upload vs ExitLag.
    param([Parameter(Mandatory)][ValidateSet('gaming','work')][string]$Direction)
    $verb = if ($Direction -eq 'gaming') { 'stop' } else { 'start' }
    $lines = @($ManagedServices | ForEach-Object { "svc=$_=$verb" })
    $lines += if ($Direction -eq 'gaming') { 'vdisp=off' } else { 'vdisp=on' }
    return $lines
}

function Invoke-ProfileSwitch {
    param(
        [Parameter(Mandatory)][ValidateSet('gaming','work')][string]$Direction,
        [switch]$RebootAfter,
        [switch]$Stagger        # -Boot: pause between starts to avoid a logon CPU storm
    )
    $mutex = [System.Threading.Mutex]::new($false, 'Local\profile-toggle')
    if (-not $mutex.WaitOne(0)) { Write-ProfileLog 'debounced: another switch in progress'; return }
    try {
        Write-ProfileLog "-> $Direction begin"
        if ($Direction -eq 'gaming') {
            # Only the first entry snapshots; a boot replay with marker=gaming keeps the
            # pre-reboot snapshot so 'ungame' still knows the real before-state.
            if (-not (Test-Path $SnapshotPath)) { Save-ProfileSnapshot -Snapshot (Get-MachineSnapshot); Write-ProfileLog 'snapshot written' }
        } else {
            if (Test-Path $SnapshotPath) { Remove-Item $SnapshotPath -Force -ErrorAction SilentlyContinue; Write-ProfileLog 'snapshot removed (work profile supersedes it)' }
        }
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
        $lines = Get-ElevatedRequestLines -Direction $Direction
        Request-Elevated -Lines $lines | Out-Null
        if ($Direction -eq 'gaming') {
            # Dual-mode is a monitor firmware flip (OSD / DisplayWidget), not a Windows
            # resolution change, so it cannot be scripted. Windows adopts 1920x1080 on
            # its own once the panel re-presents its EDID.
            # Write-ProfileLog echoes to console AND appends to the log file, so this
            # single call covers both the interactive path and yasb/AHK/-Boot, which
            # discard stdout but still read the log.
            Write-ProfileLog "Reminder: flip the PG32UCDP to FHD 480Hz dual-mode (OSD)."
        }
        Set-ProfileMarker -Value $Direction
        Write-ProfileLog "-> $Direction done"
        if ($RebootAfter) {
            # The elevated task (cold pwsh start + stopping the managed services) can
            # lose the race against a fixed-delay reboot; wait for it to consume the
            # request file before shutting down, so service/display state isn't stale.
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
    # Refuse unbound args instead of silently falling through to the bare toggle
    # (a caller passing switches as splatted strings lands here -- fail loud).
    if ($args.Count) {
        Write-Error "profile-toggle: unrecognized arguments: $($args -join ' ')"
        exit 1
    }
    if ($State) {
        Write-ProfileState
    } elseif ($Restore) {
        Invoke-ProfileRestore
    } elseif ($Boot) {
        $marker = Get-ProfileMarker
        if ($marker -eq 'work' -and (Test-Path $SnapshotPath)) {
            Write-ProfileLog 'boot: stale snapshot - restoring before the work replay'
            Invoke-ProfileRestore
        }
        Invoke-ProfileSwitch -Direction $marker -Stagger
    } elseif ($Gaming) {
        Invoke-GamingEntry -RebootAfter:$Reboot
    } elseif ($Work) {
        Invoke-ProfileSwitch -Direction 'work' -RebootAfter:$Reboot
    } else {
        # bare call (yasb pill): in a session -> restore, otherwise enter
        if ((Get-ProfileMarker) -eq 'gaming') { Invoke-ProfileRestore } else { Invoke-GamingEntry }
    }
}
