#Requires -Version 5
<#
  wezterm-freeze-probe.ps1
  Run THIS the moment WezTerm's redraw freezes (screen won't repaint until you mouse/click it).
  Snapshots every wezterm-gui process and APPENDS a timestamped block to a log you can read/share:

    Responding   True  => UI thread alive -> it's a PRESENT/occlusion throttle (something stops it drawing)
                 False => UI thread HUNG (deadlock / blocking call) -> a different class of bug
    Renderer     WebGpu(Dx12) / OpenGL / Software
    RTSS hook    is RTSSHooks64.dll (RTSS's ACTIVE present-hook) injected -> the evidence-backed stall cause
    Foreign DLLs any non-Microsoft / non-WezTerm / non-GPU module injected (other overlay hooks too:
                 Steam, Discord, NVIDIA App, etc.) -- so this isn't RTSS-tunnel-visioned

  Log:    %USERPROFILE%\.cache\wezterm-freeze-probe.log
  Invoke: wz-probe   (PowerShell profile function)   |   pwsh -NoProfile -File <thisfile>

  Why this exists: the repaint stall is intermittent and SILENT (clean wezterm log). External
  process inspection at freeze-time is the only reliable evidence -- guessing from symptoms led to a
  wrong diagnosis once already. See vault: WezTerm Repaint Stall from an Injected Overlay Hook.
#>
$ErrorActionPreference = 'SilentlyContinue'
$log = Join-Path $env:USERPROFILE '.cache\wezterm-freeze-probe.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

$L = [System.Collections.Generic.List[string]]::new()
$L.Add("==================== FREEZE PROBE  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====================")
$L.Add("Overlay/hook procs: RTSS=$([bool](Get-Process RTSS)) Afterburner=$([bool](Get-Process MSIAfterburner)) HooksLoader=$([bool](Get-Process RTSSHooksLoader64)) nvcontainer=$([bool](Get-Process nvcontainer)) Steam=$([bool](Get-Process steamwebhelper)) Discord=$([bool](Get-Process Discord))")
# RTSSHooksLoader64 is the actual global-hook host: it survives killing RTSS/Afterburner and keeps
# re-injecting RTSSHooks64.dll into every new process (2026-07-06 finding). Kill IT to stop injection.

# Third known cause, same symptom: long-uptime wezterm-mux-server degradation (global freeze, slow
# new-tab, survives GUI restart + front_end swap). Fix = restart the mux-server, not the GUI.
$mux = Get-Process wezterm-mux-server
if ($mux) {
  foreach ($m in $mux) {
    $L.Add("mux-server PID $($m.Id)  started $($m.StartTime)  uptime $((Get-Date) - $m.StartTime)  WS $([math]::Round($m.WorkingSet64/1MB))MB  handles $($m.HandleCount)")
  }
} else { $L.Add("mux-server: not running") }
$mons = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
  (($_.UserFriendlyName | Where-Object { $_ -ne 0 }) | ForEach-Object { [char]$_ }) -join ''
}
$L.Add("Active monitors: $(@($mons) -join ', ')")

$gui = @(Get-Process wezterm-gui)
if (-not $gui) { $L.Add("(no wezterm-gui processes found)") }
foreach ($p in $gui) {
  $names = $p.Modules.ModuleName
  $rend = if ($names -contains 'd3d12.dll') { 'WebGpu/Dx12' }
          elseif ($names -match 'opengl32|libGLESv2') { 'OpenGL' }
          else { 'Software?' }
  # Foreign = injected from outside WezTerm / Windows / the GPU vendor = the usual freeze culprit.
  $foreign = $p.Modules | Where-Object {
    $_.FileName -notmatch '\\WezTerm\\' -and
    $_.FileName -notmatch '\\Windows\\(System32|SysWOW64|WinSxS|SystemApps|assembly)\\' -and
    ($_.FileVersionInfo.CompanyName -notmatch 'Microsoft|NVIDIA|Intel|Advanced Micro Devices')
  } | Select-Object -ExpandProperty ModuleName -Unique
  $L.Add("")
  $L.Add("  PID $($p.Id)  started $($p.StartTime)  Responding=$($p.Responding)  Renderer=$rend")
  $L.Add("    RTSS active hook (RTSSHooks64.dll): $([bool]($names -contains 'RTSSHooks64.dll'))")
  $L.Add("    Injected foreign DLLs: $(@($foreign) -join ', ')")
}

$block = ($L -join "`r`n")
Add-Content -Path $log -Value $block
Write-Output $block
Write-Output ""
Write-Output "Appended to $log  (read it with:  Get-Content `"$log`")"
