#Requires -Version 5.1
<#
    wm-toggle.ps1 — flip the Windows WM on/off (komorebi + masir + AHK), or report its state.
    "on"  = komorebi running.  "off" (gaming) = stopped; yasb stays up as the toggle's home.
      (no args)  -> toggle the WM   (yasb pill on_left click; komorebi.ahk service-mode `x` mirrors it)
      -State     -> print the bar glyph for the current state (yasb pill run_cmd poll)
#>
param([switch]$State)

function Get-WmToggleAction {
    # Pure: given whether komorebi is running, return the komorebic invocation that flips it.
    param([Parameter(Mandatory)][bool]$Running)
    if ($Running) {
        # komorebi takes masir + AHK down with it (--ahk is EOL but functional on 0.1.41).
        return @{ Verb = 'stop'; Args = @('stop', '--ahk', '--masir') }
    }
    $cfg = Join-Path $env:KOMOREBI_CONFIG_HOME 'komorebi.json'
    return @{ Verb = 'start'; Args = @('start', '--config', $cfg, '--ahk', '--masir') }
}

function Test-KomorebiRunning {
    return $null -ne (Get-Process komorebi -ErrorAction SilentlyContinue)
}

function Write-WmState {
    # Emit the glyph as raw UTF-8 bytes straight to stdout, so it survives a redirected pipe
    # (CreateNoWindow) regardless of the console's default output encoding — pwsh otherwise
    # downgrades PUA glyphs to '?' there. on = U+F00A (nf-fa-th)  off = U+F11B (nf-fa-gamepad).
    $glyph = if (Test-KomorebiRunning) { [char]0xF00A } else { [char]0xF11B }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($glyph)
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}

function Stop-KomorebiAhk {
    # komorebi's `stop --ahk` only terminates an AHK instance komorebi spawned itself; a boot- or
    # hand-launched one survives. Anti-cheat needs AHK fully GONE, so kill the komorebi AHK explicitly
    # by command-line match — this targets only komorebi.ahk and leaves any other AHK scripts running.
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*komorebi.ahk*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Invoke-WmToggle {
    $action = Get-WmToggleAction -Running (Test-KomorebiRunning)

    # Debounce double-clicks: a second invocation mid-toggle is a no-op.
    $mutex = [System.Threading.Mutex]::new($false, 'Local\wm-toggle')
    if (-not $mutex.WaitOne(0)) { return }
    try {
        & 'komorebic-no-console.exe' @($action.Args)   # no-console variant = no flash from the bar
        if ($action.Verb -eq 'stop') { Stop-KomorebiAhk }   # --ahk doesn't reliably kill it; make sure
        "$(Get-Date -Format s)  -> $($action.Verb)" |
            Add-Content -Path (Join-Path $env:TEMP 'wm-toggle.log')
    } finally {
        $mutex.ReleaseMutex()
    }
}

# Run only when executed directly; dot-sourcing (e.g. from the Pester test) just loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    if ($State) { Write-WmState } else { Invoke-WmToggle }
}
