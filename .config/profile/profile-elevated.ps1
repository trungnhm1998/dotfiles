#Requires -Version 5.1
<#
    profile-elevated.ps1 — body of the 'dotfiles-profile-elevated' Scheduled Task
    (RunLevel Highest). Reads a one-shot request file dropped by profile-toggle.ps1,
    validates it strictly (this is a trust boundary: the file is user-writable but
    this process is elevated), acts, deletes it.
    Scope is deliberately tiny: OpenVPN agent services + bcdedit hypervisor flip.

    NOTE: the RunLevel-Highest task points at this file directly, and it is
    user-writable — accepted tradeoff on a single-user box (equivalent to
    NOPASSWD sudo on your own script). Hardening option: copy this script to an
    admin-only location (e.g. an Administrators-only ACL'd path) and point the
    scheduled task there instead.
#>
$RequestPath = Join-Path $HOME '.config\dotfiles\profile-elevated-request'
$LogPath     = Join-Path $env:TEMP 'profile-elevated.log'
$VpnServices = @('agent_ovpnconnect', 'ovpnhelper_service')

# Virtual display adapters disabled while gaming. Matched by HARDWARE ID, never by
# instance ID: instance IDs change across driver updates, and a mismatch here would
# disable the real GPU. Lowercase; the matcher lowercases its input before comparing.
$VirtualDisplayHwIds = @('root\sudomaker\sudovda', 'superdisplay\display')

function Get-ElevatedRequest {
    # Pure: request lines + age -> validated hashtable, or $null. Whitelist only.
    param([string[]]$Lines, [double]$AgeSeconds)
    if ($AgeSeconds -gt 60) { return $null }                 # stale one-shot
    $req = @{}
    foreach ($l in $Lines) {
        if ($l -match '^vpn=(stop|start)$')      { $req['vpn'] = $Matches[1] }
        elseif ($l -match '^hv=(off|auto-if-off)$') { $req['hv'] = $Matches[1] }
        elseif ($l -match '^vdisp=(off|on)$')       { $req['vdisp'] = $Matches[1] }
    }
    if ($req.Count -eq 0) { return $null }
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

function Invoke-ElevatedRequest {
    param([Parameter(Mandatory)][hashtable]$Req)
    if ($Req.vpn -eq 'stop') {
        foreach ($s in $VpnServices) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
    } elseif ($Req.vpn -eq 'start') {
        foreach ($s in $VpnServices) { Start-Service $s -ErrorAction SilentlyContinue }
    }
    if ($Req.hv -eq 'off') {
        bcdedit /set hypervisorlaunchtype off | Out-Null
        "$(Get-Date -Format s)  hypervisor OFF (reboot pending)" | Add-Content $LogPath
    } elseif ($Req.hv -eq 'auto-if-off') {
        $cur = bcdedit /enum '{current}' | Select-String 'hypervisorlaunchtype'
        # absent line = default (auto) - only flip when it is explicitly Off
        if ($cur -and $cur.ToString() -match 'Off') {
            bcdedit /set hypervisorlaunchtype auto | Out-Null
            "$(Get-Date -Format s)  hypervisor restored to AUTO - reboot needed for WSL2/Docker" | Add-Content $LogPath
        }
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
        "$(Get-Date -Format s)  request: $($req.Keys -join ',')" | Add-Content $LogPath
        Invoke-ElevatedRequest -Req $req
    }
}
