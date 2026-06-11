# recycle-worktree.ps1 - point an existing warm worktree at new work (Library untouched).
# Exit: 0 recycled, 2 error, 3 unsafe (dirty tree or editor open) - never discards work.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Branch,                  # optional: create work branch immediately after parking
    [string]$BaseRef,                 # default: origin/<default-branch>
    [string]$ProjectRel
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not (Test-Path -LiteralPath $Path)) { Write-ResultAndExit @{ error = "no such path: $Path" } 2 }
$Path = (Resolve-Path $Path).Path
$inside = git -C $Path rev-parse --is-inside-work-tree 2>$null
if ($inside -ne 'true') { Write-ResultAndExit @{ error = "$Path is not a git worktree" } 2 }

$defaultBranch = Get-DefaultBranch -RepoRoot $Path
if (-not $BaseRef) {
    if (-not $defaultBranch) { Write-ResultAndExit @{ error = 'no -BaseRef given and default branch undetectable' } 2 }
    $BaseRef = "origin/$defaultBranch"
}
if (-not $ProjectRel) {
    $rels = Get-UnityProjectRels -RepoRoot $Path
    $ProjectRel = if ($rels.Count -gt 0) { $rels[0] } else { '.' }
}
$projDir = if ($ProjectRel -eq '.') { $Path } else { Join-Path $Path $ProjectRel }

$dirty = @(git -C $Path status --porcelain)
if ($dirty.Count -gt 0) {
    Write-ResultAndExit ([ordered]@{ error = 'worktree has uncommitted changes - commit, stash, or clean them first'; dirtyFiles = @($dirty | Select-Object -First 20) }) 3
}
if (Test-UnityEditorOpen -ProjectDir $projDir) {
    Write-ResultAndExit @{ error = 'a Unity editor has this project open (Temp/UnityLockfile present) - close it first' } 3
}

$previousBranch = git -C $Path branch --show-current
git -C $Path fetch --prune 2>&1 | Out-Null
git -C $Path switch --detach $BaseRef 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-ResultAndExit @{ error = "git switch --detach $BaseRef failed" } 2 }

$newBranch = $null
if ($Branch) {
    git -C $Path show-ref --verify --quiet "refs/heads/$Branch" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-ResultAndExit @{ error = "branch '$Branch' already exists; worktree left parked at $BaseRef" } 2 }
    git -C $Path switch -c $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-ResultAndExit @{ error = "git switch -c $Branch failed; worktree left parked at $BaseRef" } 2 }
    $newBranch = $Branch
}

Write-ResultAndExit ([ordered]@{
    action         = 'recycled'
    path           = $Path
    parkedAt       = $BaseRef
    previousBranch = $previousBranch
    branch         = $newBranch
    note           = 'Library kept warm - next Unity open imports only the branch delta'
}) 0
