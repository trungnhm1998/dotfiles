# remove-worktree.ps1 - guarded teardown. Deleting a worktree throws away its warm Library;
# prefer recycle-worktree.ps1. Refuses dirty trees / unpushed branches / open editors without -Force.
# Exit: 0 removed, 2 error, 3 unsafe without -Force.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$ProjectRel,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not (Test-Path -LiteralPath $Path)) { Write-ResultAndExit @{ error = "no such path: $Path" } 2 }
$Path = (Resolve-Path $Path).Path
$inside = git -C $Path rev-parse --is-inside-work-tree 2>$null
if ($inside -ne 'true') { Write-ResultAndExit @{ error = "$Path is not a git worktree" } 2 }
$mainRoot = (Get-Worktrees -RepoRoot $Path)[0].path
if ($mainRoot -eq $Path) { Write-ResultAndExit @{ error = 'refusing to remove the main checkout' } 2 }

if (-not $ProjectRel) {
    $rels = Get-UnityProjectRels -RepoRoot $Path
    $ProjectRel = if ($rels.Count -gt 0) { $rels[0] } else { '.' }
}
$projDir = if ($ProjectRel -eq '.') { $Path } else { Join-Path $Path $ProjectRel }

$unsafe = [System.Collections.Generic.List[string]]::new()
if (Test-UnityEditorOpen -ProjectDir $projDir) { $unsafe.Add('a Unity editor has this project open') }
$dirty = @(git -C $Path status --porcelain)
if ($dirty.Count -gt 0) { $unsafe.Add("uncommitted changes ($($dirty.Count) files)") }
$branch = git -C $Path branch --show-current
if ($branch) {
    $unpushed = git -C $Path rev-list --count "origin/$branch..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0) { $unsafe.Add("branch '$branch' has no upstream (never pushed)") }
    elseif ([int]$unpushed -gt 0) { $unsafe.Add("branch '$branch' has $unpushed unpushed commits") }
}
if ($unsafe.Count -gt 0 -and -not $Force) {
    Write-ResultAndExit ([ordered]@{
        error  = 'unsafe to remove without -Force'
        issues = @($unsafe)
        hint   = 'a removed worktree loses its warm Library (hours of import value) - consider recycle-worktree.ps1 instead'
    }) 3
}

git -C $mainRoot worktree remove $(if ($Force) { '--force' }) $Path 2>&1 | ForEach-Object { Write-Verbose $_ }
if ($LASTEXITCODE -ne 0) { Write-ResultAndExit @{ error = 'git worktree remove failed (Library or Temp may be locked by another process)' } 2 }
git -C $mainRoot worktree prune 2>&1 | Out-Null

Write-ResultAndExit ([ordered]@{
    action  = 'removed'
    path    = $Path
    branch  = $branch
    note    = $(if ($branch) { "local branch '$branch' still exists; delete with: git branch -D $branch" } else { $null })
}) 0
