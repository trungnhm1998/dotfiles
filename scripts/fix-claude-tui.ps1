#Requires -Version 7
<#
.SYNOPSIS
  Sweep every running Claude Code process and repair panes whose console code page
  drifted off UTF-8 (the "garbled TUI" bug).

.DESCRIPTION
  A Windows console is a kernel object shared by all processes attached to it, not
  per-process state. So a throwaway process can FreeConsole() off its own, AttachConsole(pid)
  onto the target's, and read/write that console's code page - repairing a live pane with no
  restart and no lost session context.

  Healthy Claude Code panes read 65001. A drifted pane has been observed at 1250, which
  makes Claude Code's UTF-8 output decode as single-byte: each glyph eats ~3 cells and every
  repaint drifts further. Repainting (Ctrl+L, resize) never fixes it - a repaint does not
  re-decode bytes. Code page first, clear second.

  The process that sets the wrong code page is still unidentified, so this is a repair tool,
  not a prevention.

.PARAMETER Fix
  Actually set the code page on drifted panes. Without it the script only reports (dry run).

.PARAMETER CodePage
  Target code page. Default 65001 (UTF-8).

.PARAMETER ProcessName
  Process to sweep. Default claude.exe.

.EXAMPLE
  fix-claude-tui.ps1
  Report the code page of every Claude Code pane. Changes nothing.

.EXAMPLE
  fix-claude-tui.ps1 -Fix
  Repair every drifted pane, then press Ctrl+L in it to clear the already-damaged rows.

.NOTES
  Exit code 0 = all panes healthy (or all repaired). 1 = drifted panes remain.
  After repair the pane still shows the damage already written to its buffer; clear it with
  Ctrl+L. In Orca that keystroke is swallowed (Mod+L is sidebar.right.toggle, clear is
  Ctrl+K), so from a script write the byte straight to the pty instead:
    orca terminal send --terminal <term_id> --text "`f"
#>
[CmdletBinding()]
param(
  [switch]$Fix,
  [int]$CodePage = 65001,
  [string]$ProcessName = 'claude.exe',

  # Internal: the script re-invokes itself as a worker. FreeConsole() would detach the
  # caller from its own console, so the attach must happen in a throwaway process.
  [switch]$Worker,
  [int]$TargetPid,
  [string]$Out,
  [int]$SetCP = 0
)

$ErrorActionPreference = 'Stop'

function Invoke-Worker {
  # Runs in the throwaway process. Writes findings to a FILE, never stdout: after
  # AttachConsole succeeds, this process's stdout paints into the TARGET's pane - i.e. into
  # the very window being repaired, where the operator will never see it.
  Add-Type -Namespace ConProbe -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern uint GetConsoleOutputCP();
[DllImport("kernel32.dll", SetLastError=true)] public static extern uint GetConsoleCP();
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleOutputCP(uint cp);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleCP(uint cp);
'@

  $r = [ordered]@{ pid = $TargetPid; attached = $false }
  [void][ConProbe.Native]::FreeConsole()
  if ([ConProbe.Native]::AttachConsole([uint32]$TargetPid)) {
    $r.attached  = $true
    $r.beforeOut = [ConProbe.Native]::GetConsoleOutputCP()
    $r.beforeIn  = [ConProbe.Native]::GetConsoleCP()
    if ($SetCP -gt 0) {
      # Set both directions: a UTF-8 TUI reads keyboard input through the input code page too.
      [void][ConProbe.Native]::SetConsoleOutputCP([uint32]$SetCP)
      [void][ConProbe.Native]::SetConsoleCP([uint32]$SetCP)
      $r.afterOut = [ConProbe.Native]::GetConsoleOutputCP()
      $r.afterIn  = [ConProbe.Native]::GetConsoleCP()
    }
  } else {
    $r.lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
  }
  $r | ConvertTo-Json -Compress | Set-Content -LiteralPath $Out -Encoding utf8
}

function Invoke-Probe {
  param([int]$ProbePid, [int]$Set = 0)

  $tmp = Join-Path ([IO.Path]::GetTempPath()) "claude-cp-$ProbePid-$PID.json"
  $argv = @(
    '-NoProfile', '-NonInteractive', '-File', $PSCommandPath,
    '-Worker', '-TargetPid', $ProbePid, '-Out', $tmp
  )
  if ($Set -gt 0) { $argv += @('-SetCP', $Set) }

  try {
    Start-Process pwsh -ArgumentList $argv -NoNewWindow -Wait
    if (Test-Path -LiteralPath $tmp) { Get-Content -LiteralPath $tmp -Raw | ConvertFrom-Json }
  } finally {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
  }
}

if ($Worker) { Invoke-Worker; return }

if (-not $IsWindows) {
  Write-Error 'Windows only: a console code page is a Win32 concept. See fix-tui.sh notes.'
  exit 2
}

$targets = Get-CimInstance Win32_Process -Filter "Name='$ProcessName'" -ErrorAction SilentlyContinue
if (-not $targets) { Write-Host "No $ProcessName processes running."; exit 0 }

$rows = foreach ($t in $targets) {
  $probe = Invoke-Probe -ProbePid $t.ProcessId
  if (-not $probe) { continue }

  $healthy = $probe.attached -and $probe.beforeOut -eq $CodePage -and $probe.beforeIn -eq $CodePage
  $status  = if (-not $probe.attached) { 'no console' } elseif ($healthy) { 'ok' } else { 'DRIFTED' }

  if ($Fix -and $probe.attached -and -not $healthy) {
    $repair = Invoke-Probe -ProbePid $t.ProcessId -Set $CodePage
    if ($repair.afterOut -eq $CodePage -and $repair.afterIn -eq $CodePage) {
      $status = 'REPAIRED'
    } else {
      $status = 'FIX FAILED'
    }
  }

  # Session id, when the heartbeat file for this pid exists, so a drifted pane maps to a
  # resumable session. Do NOT join on cwd - the heartbeat cwd and the pane's displayed cwd
  # have been observed to disagree.
  $session = $null
  $hb = Join-Path $HOME ".claude\sessions\$($t.ProcessId).json"
  if (Test-Path -LiteralPath $hb) {
    $session = (Get-Content -LiteralPath $hb -Raw | ConvertFrom-Json).sessionId
  }

  [pscustomobject]@{
    Pid       = $t.ProcessId
    OutputCP  = $probe.beforeOut
    InputCP   = $probe.beforeIn
    Status    = $status
    SessionId = if ($session) { $session.Substring(0, [Math]::Min(8, $session.Length)) } else { '' }
  }
}

$rows | Sort-Object Status, Pid | Format-Table -AutoSize

$drifted = @($rows | Where-Object Status -eq 'DRIFTED')
$fixed   = @($rows | Where-Object Status -eq 'REPAIRED')

if ($fixed) {
  Write-Host ''
  Write-Host "Repaired $($fixed.Count) pane(s). The damage already in each buffer stays until you clear it:" -ForegroundColor Green
  Write-Host '  press Ctrl+L in the pane  (Orca: Ctrl+K, or `orca terminal send --terminal <id> --text "`f`")'
}
if ($drifted) {
  Write-Host ''
  Write-Host "$($drifted.Count) pane(s) drifted. Re-run with -Fix to repair." -ForegroundColor Yellow
  exit 1
}
exit 0
