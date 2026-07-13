#Requires -Version 5.1
<#
    profile-elevated.ps1 — body of the 'dotfiles-profile-elevated' Scheduled Task
    (RunLevel Highest). Reads a one-shot request file dropped by profile-toggle.ps1,
    validates it strictly (this is a trust boundary: the file is user-writable but
    this process is elevated), acts, deletes it.
    Scope is deliberately tiny: OpenVPN agent services + bcdedit hypervisor flip.
#>
$RequestPath = Join-Path $HOME '.config\dotfiles\profile-elevated-request'
$LogPath     = Join-Path $env:TEMP 'profile-elevated.log'
$VpnServices = @('agent_ovpnconnect', 'ovpnhelper_service')

function Get-ElevatedRequest {
    # Pure: request lines + age -> validated hashtable, or $null. Whitelist only.
    param([string[]]$Lines, [double]$AgeSeconds)
    if ($AgeSeconds -gt 60) { return $null }                 # stale one-shot
    $req = @{}
    foreach ($l in $Lines) {
        if ($l -match '^vpn=(stop|start)$')      { $req['vpn'] = $Matches[1] }
        elseif ($l -match '^hv=(off|auto-if-off)$') { $req['hv'] = $Matches[1] }
    }
    if ($req.Count -eq 0) { return $null }
    return $req
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
