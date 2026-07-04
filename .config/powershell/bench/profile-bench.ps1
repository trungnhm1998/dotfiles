<#
.SYNOPSIS
  PowerShell profile load-cost attribution — mirrors the interactive profile's import order.
.DESCRIPTION
  Times each heavy step of Microsoft.PowerShell_profile.ps1 in a fresh -NoProfile child, so you can
  see which imports/inits dominate "new tab/shell is slow". Run it after editing the profile to
  confirm the change. The SUM is roughly the per-shell overhead you feel when opening a tab/shell.

  Baseline history (RTX 5070 Ti box, cold-ish, N=1 — startup has high variance, eyeball trends):
    2026-07-04 before trim: SUM ~1221 ms  (posh-git 464 + Terminal-Icons 279 = 61% of it)
    2026-07-04 after  trim: expect ~350-450 ms  (posh-git / Terminal-Icons / CompletionPredictor dropped)

  Keep the step list below IN SYNC with the profile's heavy imports/inits — this is a curated mirror,
  not an auto-parse of the profile.
.EXAMPLE
  pwsh -NoProfile -NoLogo -File .\profile-bench.ps1
#>
$ErrorActionPreference = 'Continue'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Step($name, $block) {
  $t0 = $sw.Elapsed.TotalMilliseconds
  try { & $block | Out-Null } catch { Write-Host ("  ({0} FAILED: {1})" -f $name, $_.Exception.Message) }
  '{0,8:N0} ms  {1}' -f ($sw.Elapsed.TotalMilliseconds - $t0), $name
}

Step 'Import-Module PSReadLine'      { Import-Module PSReadLine }
Step 'Import-Module PSFzf'           { Import-Module PSFzf }
Step 'starship init (external call)' { & starship init powershell | Out-String }
Step 'zoxide init  (external call)'  { & { (zoxide init powershell --cmd cd | Out-String) } }
$choco = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $choco) { Step 'Import Chocolatey profile' { Import-Module $choco } }
$osc = "$HOME\Documents\PowerShell\OpenSpecCompletion.ps1"
if (Test-Path $osc) { Step 'OpenSpecCompletion.ps1 (dot-source)' { . $osc } }
$sw.Stop()
'{0,8:N0} ms  == SUM (approx per-shell profile overhead) ==' -f $sw.Elapsed.TotalMilliseconds
