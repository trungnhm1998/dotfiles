#Requires -Version 5.1
<#
    profile-elevated.ps1 — body of the 'dotfiles-profile-elevated' Scheduled Task
    (RunLevel Highest). Reads a one-shot request file dropped by profile-toggle.ps1,
    validates it strictly (this is a trust boundary: the file is user-writable but
    this process is elevated), acts, deletes it.
    Scope is deliberately tiny: whitelisted services (OpenVPN agent, Delivery Optimization) + virtual display adapters. The bcdedit hypervisor lane was removed 2026-09-02 (FACEIT/Vanguard now require VBS).

    NOTE: the RunLevel-Highest task points at this file directly, and it is
    user-writable — accepted tradeoff on a single-user box (equivalent to
    NOPASSWD sudo on your own script). Hardening option: copy this script to an
    admin-only location (e.g. an Administrators-only ACL'd path) and point the
    scheduled task there instead.
#>
$RequestPath = Join-Path $HOME '.config\dotfiles\profile-elevated-request'
$LogPath     = Join-Path $env:TEMP 'profile-elevated.log'
# Services the user half may stop/start through this task. Fixed here, never taken
# from the request file: the file is user-writable, this process is elevated.
$ManagedServices = @('agent_ovpnconnect', 'ovpnhelper_service', 'DoSvc')

# Virtual display adapters disabled while gaming. Matched by HARDWARE ID, never by
# instance ID: instance IDs change across driver updates, and a mismatch here would
# disable the real GPU. Lowercase; the matcher lowercases its input before comparing.
$VirtualDisplayHwIds = @('root\sudomaker\sudovda', 'superdisplay\display')

function Get-ElevatedRequest {
    # Pure: request lines + age -> validated hashtable, or $null. Whitelist only.
    param([string[]]$Lines, [double]$AgeSeconds)
    if ($AgeSeconds -gt 60) { return $null }                 # stale one-shot
    $req = @{ Services = @{} }
    foreach ($l in $Lines) {
        if ($l -match '^svc=([A-Za-z0-9_]+)=(stop|start)$') {
            if ($ManagedServices -contains $Matches[1]) { $req.Services[$Matches[1]] = $Matches[2] }
        } elseif ($l -match '^vdisp=(off|on)$') { $req['vdisp'] = $Matches[1] }
    }
    if ($req.Services.Count -eq 0 -and -not $req.ContainsKey('vdisp')) { return $null }
    return $req
}

function Test-VirtualDisplayHwId {
    # Pure: does this device's hardware-ID list identify one of our virtual adapters?
    # This is the safety gate. If it ever returns $true for a real GPU, `game` blanks
    # the desktop, so it is tested against the real NVIDIA and Intel ID lists.
    param([string[]]$HardwareIds)
    foreach ($h in $HardwareIds) {
        if ($h -and ($VirtualDisplayHwIds -contains $h.ToLower())) { return $true }
    }
    return $false
}

function Set-VirtualDisplay {
    param([Parameter(Mandatory)][bool]$Enabled)
    foreach ($dev in (Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)) {
        $hw = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId `
                   -KeyName DEVPKEY_Device_HardwareIds -ErrorAction SilentlyContinue).Data
        if (-not (Test-VirtualDisplayHwId -HardwareIds $hw)) { continue }
        try {
            if ($Enabled) {
                Enable-PnpDevice  -InstanceId $dev.InstanceId -Confirm:$false -ErrorAction Stop
            } else {
                Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false -ErrorAction Stop
            }
            "$(Get-Date -Format s)  vdisp $(if ($Enabled) { 'on' } else { 'off' }): $($dev.FriendlyName)" |
                Add-Content $LogPath
        } catch {
            "$(Get-Date -Format s)  ERROR vdisp $($dev.FriendlyName): $($_.Exception.Message)" |
                Add-Content $LogPath
        }
    }
}

function Stop-ServiceBounded {
    # OpenVPN services have SCM restart-on-failure (RESTART action at 1s/5s/30s), so we
    # wait with a timeout but do NOT kill; SCM treats a killed process as a crash and
    # restarts it within a second, defeating the stop. Log a warning on timeout instead.
    param([Parameter(Mandatory)][string]$Name, [int]$TimeoutSec = 20)
    $svc = Get-Service $Name -ErrorAction SilentlyContinue
    if (-not $svc -or $svc.Status -eq 'Stopped') { return }
    Stop-Service $Name -Force -NoWait -ErrorAction SilentlyContinue
    try { $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds($TimeoutSec)) }
    catch {
        "$(Get-Date -Format s)  WARN svc $Name still not Stopped after ${TimeoutSec}s" | Add-Content $LogPath
    }
}

function Invoke-ElevatedRequest {
    param([Parameter(Mandatory)][hashtable]$Req)
    foreach ($name in $Req.Services.Keys) {
        # Diff-based: DoSvc is trigger-started and the OpenVPN agent has a restart
        # failure action, so "already in the requested state" is success.
        if ($Req.Services[$name] -eq 'stop') { Stop-ServiceBounded -Name $name }
        else { Start-Service $name -ErrorAction SilentlyContinue }
        "$(Get-Date -Format s)  svc $name $($Req.Services[$name]) -> $((Get-Service $name -ErrorAction SilentlyContinue).Status)" |
            Add-Content $LogPath
    }
    if ($Req.vdisp -eq 'off') {
        Set-VirtualDisplay -Enabled $false
    } elseif ($Req.vdisp -eq 'on') {
        Set-VirtualDisplay -Enabled $true
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not (Test-Path $RequestPath)) { return }
    $age   = ((Get-Date) - (Get-Item $RequestPath).LastWriteTime).TotalSeconds
    $lines = Get-Content -Path $RequestPath -ErrorAction SilentlyContinue
    Remove-Item $RequestPath -Force -ErrorAction SilentlyContinue   # one-shot: consume before acting
    $req = Get-ElevatedRequest -Lines $lines -AgeSeconds $age
    if ($req) {
        "$(Get-Date -Format s)  request: svc=$($req.Services.Keys -join ',') vdisp=$($req.vdisp)" | Add-Content $LogPath
        Invoke-ElevatedRequest -Req $req
    }
}
