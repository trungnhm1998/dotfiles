# Point every Orca-registered repo at the shared worktree setup hook.
# Orca exposes hookSettings only in its UI (no CLI, no accessibility tree), so this
# patches its state file directly. Orca must be closed or it will overwrite the edit.
#
#   pwsh -NoProfile -File "$env:USERPROFILE\dotfiles\scripts\orca-apply-worktree-hooks.ps1"

$data = Join-Path $env:APPDATA 'Orca\profiles\local-default\orca-data.json'
if (-not (Test-Path $data)) { Write-Error "orca-data.json not found at $data"; exit 1 }

if (Get-Process -Name 'Orca' -ErrorAction SilentlyContinue) {
  Write-Error 'Orca is running. Quit it first, or it will overwrite these changes on exit.'
  exit 1
}

$backup = "$data.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item $data $backup
Write-Host "backup: $backup"

$setup = 'pwsh -NoProfile -File "$env:USERPROFILE\dotfiles\scripts\worktree-setup.ps1"'
$json  = Get-Content $data -Raw | ConvertFrom-Json -Depth 100

foreach ($repo in $json.repos) {
  $hs = $repo.hookSettings
  if (-not $hs) {
    $hs = [pscustomobject]@{ mode = 'auto'; scripts = [pscustomobject]@{ setup = ''; archive = '' } }
    $repo | Add-Member -NotePropertyName hookSettings -NotePropertyValue $hs -Force
  }
  if (-not $hs.scripts) {
    $hs | Add-Member -NotePropertyName scripts -NotePropertyValue ([pscustomobject]@{ setup = ''; archive = '' }) -Force
  }
  $hs.scripts | Add-Member -NotePropertyName setup -NotePropertyValue $setup -Force
  $hs | Add-Member -NotePropertyName mode                     -NotePropertyValue 'auto'             -Force
  $hs | Add-Member -NotePropertyName setupRunPolicy           -NotePropertyValue 'run-by-default'   -Force
  # Seeding must finish before the agent reads .claude/settings.local.json and the skills.
  $hs | Add-Member -NotePropertyName setupAgentStartupPolicy  -NotePropertyValue 'wait-for-setup'   -Force
  Write-Host "patched: $($repo.path)"
}

$json | ConvertTo-Json -Depth 100 | Set-Content $data -Encoding utf8
Write-Host "`ndone - reopen Orca."
