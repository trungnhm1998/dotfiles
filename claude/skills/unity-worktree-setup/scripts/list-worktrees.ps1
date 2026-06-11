# list-worktrees.ps1 - computed worktree registry (replaces hand-maintained slot files).
# Exit: 0. Output: JSON on stdout; recyclable=true rows are safe to point at new work.
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$DefaultBranch,
    [string]$ProjectRel
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not $RepoRoot) { $RepoRoot = Get-RepoRoot }
if (-not $RepoRoot) { Write-ResultAndExit @{ error = 'not inside a git repository' } 2 }
if (-not $DefaultBranch) { $DefaultBranch = Get-DefaultBranch -RepoRoot $RepoRoot }
if (-not $ProjectRel) {
    $rels = Get-UnityProjectRels -RepoRoot $RepoRoot
    $ProjectRel = if ($rels.Count -gt 0) { $rels[0] } else { '.' }
}

$rows = foreach ($wt in (Get-Worktrees -RepoRoot $RepoRoot)) {
    Get-WorktreeStatus -Worktree $wt -ProjectRel $ProjectRel -DefaultBranch $DefaultBranch
}

Write-ResultAndExit ([ordered]@{
    repoRoot      = $RepoRoot
    defaultBranch = $DefaultBranch
    projectRel    = $ProjectRel
    worktrees     = @($rows)
}) 0
