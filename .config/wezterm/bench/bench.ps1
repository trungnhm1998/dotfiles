<#
.SYNOPSIS
  WezTerm-on-Windows performance harness: measure startup / interactive paint latency across config variants.
.DESCRIPTION
  Reuses WezTerm's built-in `paint_impl elapsed=` DEBUG instrumentation. Pins confounders (RTSS closed,
  mux cold/warm), discards a warm-up run, reports median+p95 over N runs. See the design spec:
  docs/superpowers/specs/2026-07-01-wezterm-windows-perf-harness-design.md
.EXAMPLE
  ./bench.ps1 -Variant full -Mode startup -Warm
.EXAMPLE
  ./bench.ps1 -Variant full -Mode interactive
#>
param(
  [Parameter(Mandatory)][ValidateSet('stock','full','opengl','no-updatestatus','empty','plugins-only','wt')]
  [string]$Variant,
  [Parameter(Mandatory)][ValidateSet('startup','interactive')][string]$Mode,
  [int]$Runs = 10,
  [switch]$Cold,
  [switch]$Warm
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/bench.lib.ps1"

$WezGui = (Get-Command wezterm-gui -EA SilentlyContinue).Source ?? 'C:\Program Files\WezTerm\wezterm-gui.exe'
$WezCli = (Get-Command wezterm     -EA SilentlyContinue).Source ?? 'C:\Program Files\WezTerm\wezterm.exe'
$ConfigDir = "$PSScriptRoot/configs"
$ResultsDir = "$PSScriptRoot/results"; New-Item -ItemType Directory -Force $ResultsDir | Out-Null

# --- confounder preflight -------------------------------------------------
$hookers = Get-Process RTSS, MSIAfterburner -EA SilentlyContinue
if ($hookers) { throw "Close RTSS/MSI Afterburner first (present-hook confounder): $($hookers.Name -join ', ')." }
if (-not $Cold -and -not $Warm) { $Warm = $true }  # default: warm (the day-to-day case)

# --- variant -> launch spec ----------------------------------------------
function Get-LaunchSpec([string]$v) {
  switch ($v) {
    'stock'           { @{ Exe=$WezGui; Args=@('-n','start','--','pwsh','-NoLogo');                                          Env=@{} } }
    'full'            { @{ Exe=$WezGui; Args=@('start','--','pwsh','-NoLogo');                                               Env=@{} } }
    'opengl'          { @{ Exe=$WezGui; Args=@('--config','front_end="OpenGL"','start','--','pwsh','-NoLogo');               Env=@{} } }
    'no-updatestatus' { @{ Exe=$WezGui; Args=@('start','--','pwsh','-NoLogo');                                               Env=@{ WZB_NO_UPDATESTATUS='1' } } }
    'empty'           { @{ Exe=$WezGui; Args=@('--config-file',"$ConfigDir/empty.lua",'start','--','pwsh','-NoLogo');        Env=@{} } }
    'plugins-only'    { @{ Exe=$WezGui; Args=@('--config-file',"$ConfigDir/plugins-only.lua",'start','--','pwsh','-NoLogo'); Env=@{} } }
    'wt'              { @{ Exe=(Get-Command wt).Source; Args=@(); Env=@{} } }
  }
}

function Kill-Wez { Get-Process wezterm-gui, wezterm-mux-server -EA SilentlyContinue | Stop-Process -Force; Start-Sleep -ms 300 }

# --- one startup sample: spawn -> window visible + responding -------------
function Measure-StartupOnce([hashtable]$Spec, [bool]$ColdRun) {
  if ($ColdRun) { Kill-Wez }
  foreach ($k in $Spec.Env.Keys) { Set-Item "env:$k" $Spec.Env[$k] }
  $procName = if ($Variant -eq 'wt') { 'WindowsTerminal' } else { 'wezterm-gui' }
  $before = @(Get-Process $procName -EA SilentlyContinue | Select-Object -Expand Id)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Start-Process -FilePath $Spec.Exe -ArgumentList $Spec.Args | Out-Null
  $newProc = $null
  while ($sw.ElapsedMilliseconds -lt 15000) {
    Start-Sleep -Milliseconds 10
    $newProc = Get-Process $procName -EA SilentlyContinue | Where-Object { $_.Id -notin $before }
    if ($newProc -and $newProc[0].MainWindowHandle -ne 0 -and $newProc[0].Responding) { break }
  }
  $sw.Stop()
  foreach ($k in $Spec.Env.Keys) { Remove-Item "env:$k" -EA SilentlyContinue }
  if ($newProc) { Stop-Process -Id $newProc[0].Id -Force -EA SilentlyContinue }
  Start-Sleep -Milliseconds 200
  $sw.ElapsedMilliseconds
}

# --- run loop (discard warm-up, aggregate) --------------------------------
$spec = Get-LaunchSpec $Variant
if ($Warm -and $Variant -eq 'full') {
  # ensure the mux-server is up so we measure gui/config startup, not mux spawn
  Start-Process -FilePath $WezGui -ArgumentList @('start','--','pwsh','-NoLogo') | Out-Null
  Start-Sleep -Seconds 2
}
$samples = for ($i = 0; $i -le $Runs; $i++) {          # $Runs+1: first is warm-up
  $ms = Measure-StartupOnce $spec ([bool]$Cold)
  if ($i -gt 0) { $ms }                                 # discard warm-up
}
$samples = @($samples | ForEach-Object { [double]$_ })
$row = [pscustomobject]@{
  Variant  = $Variant; Mode = "startup($(if($Cold){'cold'}else{'warm'}))"; N = $samples.Count
  MedianMs = Get-Percentile -Values $samples -P 50
  P95Ms    = Get-Percentile -Values $samples -P 95
  MaxMs    = Get-Percentile -Values $samples -P 100
}
$table = Format-BenchTable @($row)
$verLine = "WezTerm: $(& $WezCli --version)"
$out = "$verLine`n`n$table"
$out | Tee-Object -FilePath "$ResultsDir/$(Get-Date -Format yyyyMMdd-HHmmss)-startup-$Variant.md"
