#Requires -Version 5.1
param([int]$DurationSec = 0)
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class FgWin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
function Get-FgInfo {
  $hwnd = [FgWin]::GetForegroundWindow()
  $title = New-Object System.Text.StringBuilder 512
  $class = New-Object System.Text.StringBuilder 256
  [void][FgWin]::GetWindowText($hwnd, $title, 512)
  [void][FgWin]::GetClassName($hwnd, $class, 256)
  $wpid = [uint32]0; [void][FgWin]::GetWindowThreadProcessId($hwnd, [ref]$wpid)
  $proc = Get-Process -Id $wpid -ErrorAction SilentlyContinue
  $rect = New-Object FgWin+RECT; [void][FgWin]::GetWindowRect($hwnd, [ref]$rect)
  [pscustomobject]@{ Time=(Get-Date -Format 'HH:mm:ss.fff'); Hwnd=("0x{0:X}" -f [int64]$hwnd)
    Visible=[FgWin]::IsWindowVisible($hwnd); Exe= if($proc){$proc.ProcessName}else{'?'}
    Class=$class.ToString(); Title=$title.ToString(); W=$rect.Right-$rect.Left; H=$rect.Bottom-$rect.Top }
}
$log = Join-Path $env:TEMP 'komorebi-focus-log.txt'
"=== started $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8
$stateJson = & komorebic.exe state 2>$null | Out-String
$managed = [regex]::Matches($stateJson, '"hwnd":\s*(\d+)') | ForEach-Object { [int64]$_.Groups[1].Value }
$managedSet = [System.Collections.Generic.HashSet[int64]]::new(); foreach($h in $managed){[void]$managedSet.Add($h)}
$last=''; $deadline = if($DurationSec -gt 0){(Get-Date).AddSeconds($DurationSec)}else{$null}
$msrdcStart = $null
$msrdcDwells = [System.Collections.Generic.List[string]]::new()
while($true){ if($deadline -and (Get-Date) -gt $deadline){break}
  $i=Get-FgInfo; $key="$($i.Exe)|$($i.Class)|$($i.Title)"
  $fgHwnd = [int64][FgWin]::GetForegroundWindow()
  $managedFlag = if($managedSet.Contains($fgHwnd)){'MANAGED'}else{'UNMANAGED'}
  $isWslgSteal = ($i.Exe -eq 'msrdc' -and $i.Class -eq 'TscShellContainerClass')
  if ($isWslgSteal -and -not $msrdcStart) { $msrdcStart = Get-Date }
  elseif (-not $isWslgSteal -and $msrdcStart) {
    $sec = ((Get-Date) - $msrdcStart).TotalSeconds
    $msrdcDwells.Add(("{0:F2}s dwell ended -> {1} | {2}" -f $sec, $i.Exe, $i.Title))
    $msrdcStart = $null
  }
  if($key -ne $last){
    $line = "$($i.Time) | $managedFlag | vis=$($i.Visible) | $($i.Exe) | $($i.Hwnd) | $($i.W)x$($i.H) | class=$($i.Class) | $($i.Title)"
    $line | Add-Content $log -Encoding utf8; Write-Output $line; $last=$key }
  Start-Sleep -Milliseconds 250 }
if ($msrdcStart) {
  $sec = ((Get-Date) - $msrdcStart).TotalSeconds
  $msrdcDwells.Add(("{0:F2}s dwell (still on msrdc at end)" -f $sec))
}
Write-Output "--- WSLg steal summary ---"
if ($msrdcDwells.Count -eq 0) { Write-Output "  no msrdc focus steals detected" }
else { $msrdcDwells | ForEach-Object { Write-Output "  $_" } }
Write-Output "Done -> $log"
