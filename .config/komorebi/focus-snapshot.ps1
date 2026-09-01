#Requires -Version 5.1
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinApi {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int Left, Top, Right, Bottom; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
}
"@

function Read-Window([IntPtr]$hwnd) {
    $title = New-Object System.Text.StringBuilder 512
    $class = New-Object System.Text.StringBuilder 256
    [void][WinApi]::GetWindowText($hwnd, $title, 512)
    [void][WinApi]::GetClassName($hwnd, $class, 256)
    $wpid = [uint32]0
    [void][WinApi]::GetWindowThreadProcessId($hwnd, [ref]$wpid)
    $proc = Get-Process -Id $wpid -ErrorAction SilentlyContinue
    $rect = New-Object WinApi+RECT
    [void][WinApi]::GetWindowRect($hwnd, [ref]$rect)
    [pscustomobject]@{
        Hwnd    = ("0x{0:X}" -f [int64]$hwnd)
        Visible = [WinApi]::IsWindowVisible($hwnd)
        Exe     = if ($proc) { $proc.ProcessName } else { '?' }
        Class   = $class.ToString()
        Title   = $title.ToString()
        W       = $rect.Right - $rect.Left
        H       = $rect.Bottom - $rect.Top
    }
}

Write-Host '=== OS FOREGROUND ===' -ForegroundColor Cyan
$fg = Read-Window ([WinApi]::GetForegroundWindow())
$fg | Format-List

Write-Host '=== KOMOREBI QUERIES ===' -ForegroundColor Cyan
foreach ($q in @('focused-monitor-index','focused-workspace-name','focused-workspace-index','focused-window-index','focused-container-kind')) {
    $v = & komorebic.exe query $q 2>$null
    Write-Host ("  {0}: {1}" -f $q, ($v -join ' '))
}

Write-Host '=== KOMOREBI MANAGED HWNDS ===' -ForegroundColor Cyan
$stateJson = & komorebic.exe state 2>$null | Out-String
$managed = [regex]::Matches($stateJson, '"hwnd":\s*(\d+)') | ForEach-Object { [int64]$_.Groups[1].Value }
$managedSet = [System.Collections.Generic.HashSet[int64]]::new()
foreach ($h in $managed) { [void]$managedSet.Add($h) }
Write-Host ("  managed window count: {0}" -f $managedSet.Count)

$fgHwnd = [int64][WinApi]::GetForegroundWindow()
if ($managedSet.Contains($fgHwnd)) {
    Write-Host '  >> FOREGROUND IS MANAGED (border expected)' -ForegroundColor Green
} else {
    Write-Host '  >> FOREGROUND NOT MANAGED (border would disappear)' -ForegroundColor Red
}

Write-Host '=== WORK-APP WINDOWS ===' -ForegroundColor Cyan
$targets = @('claude','wezterm-gui','Obsidian','Discord','slack','Spotify','Orca','Unity','WindowsTerminal','AutoHotkey64','masir','komorebi','explorer','Cursor','Code')
$rows = [System.Collections.Generic.List[object]]::new()
[WinApi]::EnumWindows([WinApi+EnumProc]{ param($h,$l)
    $w = Read-Window $h
    if ($targets -contains $w.Exe) { [void]$rows.Add($w) }
    return $true
}, [IntPtr]::Zero) | Out-Null
$rows | Sort-Object Exe, Title | Format-Table Hwnd, Visible, Exe, W, H, Class, Title -AutoSize

Write-Host '=== FOCUS-THEFT CANDIDATES (hidden or tiny) ===' -ForegroundColor Yellow
$rows | Where-Object { -not $_.Visible -or $_.W -lt 80 -or $_.H -lt 80 } |
    Format-Table Hwnd, Visible, Exe, W, H, Class, Title -AutoSize

Write-Host '=== MANAGED HWND DETAIL (match foreground?) ===' -ForegroundColor Cyan
foreach ($h in $managed) {
    $w = Read-Window ([IntPtr]$h)
    $mark = if ($h -eq $fgHwnd) { ' <-- FOREGROUND' } else { '' }
    Write-Host ("  {0} | vis={1} | {2} | {3}x{4} | {5}{6}" -f $w.Hwnd, $w.Visible, $w.Exe, $w.W, $w.H, $w.Title, $mark)
}
