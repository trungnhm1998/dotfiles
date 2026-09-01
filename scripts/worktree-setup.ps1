# Orca worktree setup hook. Configure once per repo in Orca's setup-script field as:
#   pwsh -NoProfile -File "$env:USERPROFILE\dotfiles\scripts\worktree-setup.ps1"
# Keeping the logic here (not in Orca's field) means changes are version-controlled
# and never require re-editing every repo through the Orca UI.
param([string]$WorktreePath)

$ErrorActionPreference = 'Continue'

$dest =
  if     ($WorktreePath)            { $WorktreePath }
  elseif ($env:ORCA_WORKTREE_PATH)  { $env:ORCA_WORKTREE_PATH }
  else                              { (Get-Location).Path }

# Must be git-bash: bare `bash` on PATH is the WSL launcher, which cannot read Windows paths.
$bash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path $bash)) { Write-Error "git-bash not found at $bash"; exit 1 }

& $bash "$env:USERPROFILE/dotfiles/scripts/worktree-seed.sh" $dest
exit $LASTEXITCODE
