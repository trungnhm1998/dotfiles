#Requires -Version 5.1
<#
    yasb-toggle.ps1 — toggle the YASB bar and komorebi's reserved work area together.
    Visible = yasb running + work_area_offset values from komorebi.json.
    Hidden  = yasb stopped (process killed, RAM freed) + offsets zeroed (tiles edge-to-edge).
    State is the live process — no marker file; self-heals if yasb died some other way.
      (no args)  -> toggle                    (komorebi.ahk Hyper+B; pwsh `bar`)
      -DryRun    -> print planned commands, change nothing
#>
param(
    [switch]$DryRun
)

$KomorebiJson = Join-Path $HOME '.config\komorebi\komorebi.json'

function Test-YasbRunning {
    # Exact name (verified against the live binary) — 'yasb*' would match a transient yasbc.
    return $null -ne (Get-Process yasb -ErrorAction SilentlyContinue)
}

function Get-MonitorOffsets {
    # Monitors that reserve space in komorebi.json, with their offsets.
    # json is the single source of truth — the restore path re-applies exactly these values.
    $cfg = Get-Content $KomorebiJson -Raw | ConvertFrom-Json
    $offsets = @()
    for ($i = 0; $i -lt $cfg.monitors.Count; $i++) {
        $off = $cfg.monitors[$i].work_area_offset
        if ($null -ne $off) {
            $offsets += [pscustomobject]@{
                Index = $i; Left = $off.left; Top = $off.top; Right = $off.right; Bottom = $off.bottom
            }
        }
    }
    return $offsets
}

function Set-WorkAreaOffsets {
    # Applies (or, with -Zero, clears) each monitor's offset via komorebic — realtime, no restart.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Offsets,
        [switch]$Zero,
        [switch]$DryRun
    )
    foreach ($m in $Offsets) {
        $cliArgs = if ($Zero) { @($m.Index, 0, 0, 0, 0) }
                   else       { @($m.Index, $m.Left, $m.Top, $m.Right, $m.Bottom) }
        if ($DryRun) {
            "komorebic monitor-work-area-offset $($cliArgs -join ' ')"
            continue
        }
        # Failure tolerated: komorebi may be stopped (gaming profile) — bar toggle must still work.
        try { & komorebic monitor-work-area-offset @cliArgs 2>$null | Out-Null } catch {}
    }
}

function Invoke-YasbToggle {
    param([switch]$DryRun)

    $running = Test-YasbRunning
    $offsets = Get-MonitorOffsets

    # Debounce double-fires (hotkey mash): second invocation mid-toggle is a no-op.
    $mutex = [System.Threading.Mutex]::new($false, 'Local\yasb-toggle')
    if (-not $mutex.WaitOne(0)) { return }
    try {
        if ($running) {
            if ($DryRun) { 'yasbc stop' } else { & yasbc stop --silent }
            Set-WorkAreaOffsets -Offsets $offsets -Zero -DryRun:$DryRun
        } else {
            # Offsets BEFORE start so the bar never overlaps tiles.
            Set-WorkAreaOffsets -Offsets $offsets -DryRun:$DryRun
            if ($DryRun) { 'yasbc start' } else { & yasbc start --silent }
        }
        if (-not $DryRun) {
            "$(Get-Date -Format s)  -> $(if ($running) { 'hide' } else { 'show' })" |
                Add-Content -Path (Join-Path $env:TEMP 'yasb-toggle.log')
        }
    } finally {
        $mutex.ReleaseMutex()
    }
}

# Run only when executed directly; dot-sourcing just loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-YasbToggle -DryRun:$DryRun
}
