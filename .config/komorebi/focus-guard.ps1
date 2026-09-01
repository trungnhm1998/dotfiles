#Requires -Version 5.1
# Restores OS foreground to komorebi's focused managed hwnd when WSLg (msrdc) steals it.
# Komorebi borders follow GetForegroundWindow(); ignore_rules alone cannot keep borders focused.
$ErrorActionPreference = 'SilentlyContinue'
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class Fg {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  public const byte VK_MENU = 0x12; public const uint KEYEVENTF_KEYUP = 0x0002;
}
"@
$mutex = [System.Threading.Mutex]::new($false, 'Local\komorebi-wslg-focus-guard')
if (-not $mutex.WaitOne(0)) { exit 0 }

function Get-FgInfo {
  $hwnd = [Fg]::GetForegroundWindow()
  if ($hwnd -eq [IntPtr]::Zero) { return $null }
  $class = New-Object System.Text.StringBuilder 256
  [void][Fg]::GetClassName($hwnd, $class, 256)
  $wpid = [uint32]0; [void][Fg]::GetWindowThreadProcessId($hwnd, [ref]$wpid)
  $proc = Get-Process -Id $wpid -ErrorAction SilentlyContinue
  [pscustomobject]@{ Hwnd=$hwnd; Visible=[Fg]::IsWindowVisible($hwnd); Exe= if($proc){$proc.ProcessName}else{'?'}; Class=$class.ToString() }
}

function Set-FgWindow([IntPtr]$hwnd) {
  [Fg]::keybd_event([Fg]::VK_MENU, 0, 0, [UIntPtr]::Zero)
  [void][Fg]::SetForegroundWindow($hwnd)
  [Fg]::keybd_event([Fg]::VK_MENU, 0, [Fg]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Get-KomorebiFocusedHwnd {
  try {
    $mi = [int](& komorebic.exe query focused-monitor-index 2>$null)
    $wi = [int](& komorebic.exe query focused-workspace-index 2>$null)
    $kind = ((& komorebic.exe query focused-container-kind 2>$null) | Out-String).Trim()
    $state = & komorebic.exe state 2>$null | ConvertFrom-Json
    $ws = $state.monitors.elements[$mi].workspaces.elements[$wi]
    if ($kind -eq 'Floating') {
      $fi = [int](& komorebic.exe query focused-window-index 2>$null)
      if (-not $ws.floating_windows.elements[$fi]) { return [IntPtr]::Zero }
      return [IntPtr]$ws.floating_windows.elements[$fi].hwnd
    }
    $ci = [int](& komorebic.exe query focused-container-index 2>$null)
    $wndx = [int](& komorebic.exe query focused-window-index 2>$null)
    if (-not $ws.containers.elements[$ci]) { return [IntPtr]::Zero }
    if (-not $ws.containers.elements[$ci].windows.elements[$wndx]) { return [IntPtr]::Zero }
    return [IntPtr]$ws.containers.elements[$ci].windows.elements[$wndx].hwnd
  } catch {
    return [IntPtr]::Zero
  }
}

$log = Join-Path $env:TEMP 'wslg-guard.log'
"=== guard v3 started $(Get-Date -Format o) pid=$PID ===" | Out-File $log -Encoding utf8
$lastManaged = [IntPtr]::Zero
$lastRecover = [DateTime]::MinValue

while ($true) {
  $fg = Get-FgInfo
  if (-not $fg) { Start-Sleep -Milliseconds 50; continue }
  $isWslgSteal = ($fg.Exe -eq 'msrdc' -and $fg.Class -eq 'TscShellContainerClass' -and -not $fg.Visible)

  if (-not $isWslgSteal) {
    $lastManaged = $fg.Hwnd
    Start-Sleep -Milliseconds 100
    continue
  }

  if (((Get-Date) - $lastRecover).TotalMilliseconds -lt 250) {
    Start-Sleep -Milliseconds 50
    continue
  }

  $target = Get-KomorebiFocusedHwnd
  if ($target -eq [IntPtr]::Zero) { $target = $lastManaged }
  if ($target -eq [IntPtr]::Zero) {
    Start-Sleep -Milliseconds 50
    continue
  }

  $t0 = Get-Date
  $stamp = $t0.ToString('HH:mm:ss.fff')
  "STEAL $stamp -> restore komorebi hwnd=0x{0:X}" -f [int64]$target | Add-Content $log -Encoding utf8
  Set-FgWindow $target
  $lastRecover = Get-Date
  $ms = [int]((Get-Date) - $t0).TotalMilliseconds
  $now = Get-FgInfo
  $nowKey = if ($now) { "0x{0:X} $($now.Exe)" -f [int64]$now.Hwnd } else { '?' }
  "RECOVERED ${stamp} in ${ms}ms -> $nowKey" | Add-Content $log -Encoding utf8
  Start-Sleep -Milliseconds 50
}
