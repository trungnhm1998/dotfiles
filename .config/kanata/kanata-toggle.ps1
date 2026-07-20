#Requires -Version 5.1
<#
    kanata-toggle.ps1 — flip the 60% keyboard remap on/off, or report its state.
    "work" = kanata.exe running (Voyager-port layout).  "gaming" = stopped (raw 60%).
      (no args)  -> toggle kanata           (yasb pill on_left click; komorebi.ahk Hyper+G)
      -Off       -> force-stop, idempotent   (komorebi.ahk service-mode `g` — unified gaming)
      -State     -> print the bar glyph for the current state (yasb pill run_cmd poll)
#>
param(
    [switch]$State,
    [switch]$Off
)

function Get-KanataToggleAction {
    # Pure: given whether kanata is running, return the action that flips it.
    param([Parameter(Mandatory)][bool]$Running)
    if ($Running) {
        return @{ Verb = 'stop' }
    }
    $cfg = Join-Path $env:XDG_CONFIG_HOME 'kanata\kanata.win.kbd'
    return @{ Verb = 'start'; Cfg = $cfg }
}

function Get-KanataExe {
    $bundled = Join-Path $env:LOCALAPPDATA 'Programs\kanata\kanata.exe'
    if (Test-Path $bundled) { return $bundled }
    $cmd = Get-Command kanata -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $bundled   # best-effort; Start-Process surfaces a clear error if missing
}

function Test-KanataRunning {
    # kanata* — a scoop install runs 'kanata_windows_*_x64'; the GitHub-release exe is 'kanata'.
    return $null -ne (Get-Process kanata* -ErrorAction SilentlyContinue)
}

function Stop-Kanata {
    # kanata* — also kills the scoop shim ('kanata') AND its worker ('kanata_windows_*_x64');
    # stopping the shim alone orphans the worker and the keyboard stays remapped.
    Get-Process kanata* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Write-KanataState {
    # Raw UTF-8 bytes straight to stdout so the PUA glyph survives yasb's redirected
    # pipe (same reason as wm-toggle.ps1). work = U+F11C (keyboard)  gaming = U+F11B (gamepad).
    $glyph = if (Test-KanataRunning) { [char]0xF11C } else { [char]0xF11B }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($glyph)
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}

function Invoke-KanataToggle {
    param([switch]$ForceOff)

    $running = Test-KanataRunning

    # -Off is idempotent: stop if running, else no-op (used by service-mode `g`).
    if ($ForceOff) {
        if ($running) { Stop-Kanata }
        return
    }

    $action = Get-KanataToggleAction -Running $running

    # Debounce double-clicks: a second invocation mid-toggle is a no-op.
    $mutex = [System.Threading.Mutex]::new($false, 'Local\kanata-toggle')
    if (-not $mutex.WaitOne(0)) { return }
    try {
        if ($action.Verb -eq 'stop') {
            Stop-Kanata
        } else {
            # --no-wait: without it a config parse error blocks forever on kanata's
            # "Press enter to exit" prompt behind the hidden window. The process lingers,
            # Test-KanataRunning reports it alive, and the yasb pill claims the keyboard
            # is remapped when it is not.
            Start-Process -FilePath (Get-KanataExe) -ArgumentList '--cfg', $action.Cfg, '--no-wait' -WindowStyle Hidden
        }
        "$(Get-Date -Format s)  -> $($action.Verb)" |
            Add-Content -Path (Join-Path $env:TEMP 'kanata-toggle.log')
    } finally {
        $mutex.ReleaseMutex()
    }
}

# Run only when executed directly; dot-sourcing (Pester) just loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    if ($State)    { Write-KanataState }
    elseif ($Off)  { Invoke-KanataToggle -ForceOff }
    else           { Invoke-KanataToggle }
}
