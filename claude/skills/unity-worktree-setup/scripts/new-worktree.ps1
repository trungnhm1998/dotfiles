# new-worktree.ps1 - create a sibling worktree for a branch and seed its Library by copy.
# Prefers recycling an existing warm worktree: exits 4 with candidates unless -ForceNew.
# Exit: 0 created, 2 error, 4 recyclable worktree available (use recycle-worktree.ps1 or -ForceNew).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Branch,
    [string]$BaseRef,                 # default: origin/<default-branch>
    [string]$Path,                    # default: <parent>/<repoName>-wt-<branch-slug>
    [string]$RepoRoot,
    [string]$ProjectRel,
    [switch]$ForceNew,
    [switch]$NoSeed,
    [int]$MinDonorMB = 200
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not $RepoRoot) { $RepoRoot = Get-RepoRoot }
if (-not $RepoRoot) { Write-ResultAndExit @{ error = 'not inside a git repository' } 2 }
$defaultBranch = Get-DefaultBranch -RepoRoot $RepoRoot
if (-not $BaseRef) {
    if (-not $defaultBranch) { Write-ResultAndExit @{ error = 'no -BaseRef given and default branch undetectable' } 2 }
    $BaseRef = "origin/$defaultBranch"
}
if (-not $ProjectRel) {
    $rels = Get-UnityProjectRels -RepoRoot $RepoRoot
    $ProjectRel = if ($rels.Count -gt 0) { $rels[0] } else { '.' }
}

git -C $RepoRoot show-ref --verify --quiet "refs/heads/$Branch" 2>$null
if ($LASTEXITCODE -eq 0) { Write-ResultAndExit @{ error = "branch '$Branch' already exists - check it out in an existing worktree instead" } 2 }

$worktrees = Get-Worktrees -RepoRoot $RepoRoot

# Warm worktrees are the asset: reuse before creating (each new Library costs disk + a copy/import).
if (-not $ForceNew) {
    $recyclable = @($worktrees | Select-Object -Skip 1 | ForEach-Object {
        Get-WorktreeStatus -Worktree $_ -ProjectRel $ProjectRel -DefaultBranch $defaultBranch
    } | Where-Object { $_.recyclable -and $_.libraryWarm })
    if ($recyclable.Count -gt 0) {
        Write-ResultAndExit ([ordered]@{
            action     = 'recycle-instead'
            message    = 'warm recyclable worktree(s) found; run recycle-worktree.ps1 -Path <path> -Branch <branch>, or re-run with -ForceNew'
            candidates = @($recyclable | ForEach-Object { $_.path })
        }) 4
    }
}

if (-not $Path) {
    $slug = $Branch -replace '[^A-Za-z0-9._-]', '-'
    $Path = Join-Path (Split-Path $RepoRoot -Parent) ("{0}-wt-{1}" -f (Split-Path $RepoRoot -Leaf), $slug)
}
if (Test-Path -LiteralPath $Path) { Write-ResultAndExit @{ error = "target path already exists: $Path" } 2 }

git -C $RepoRoot fetch --prune 2>&1 | Out-Null
git -C $RepoRoot worktree add --detach $Path $BaseRef 2>&1 | ForEach-Object { Write-Verbose $_ }
if ($LASTEXITCODE -ne 0) { Write-ResultAndExit @{ error = "git worktree add failed (base ref '$BaseRef')" } 2 }
git -C $Path switch -c $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-ResultAndExit @{ error = "worktree created at $Path but 'git switch -c $Branch' failed" } 2 }
if (Test-Path -LiteralPath (Join-Path $Path '.gitmodules')) {
    git -C $Path submodule update --init --recursive 2>&1 | Out-Null
}

# Seed Library from the leanest warm donor so first editor open imports only the delta.
$seed = $null
if (-not $NoSeed) {
    $donor = Select-DonorLibrary -Worktrees $worktrees -ProjectRel $ProjectRel -MinDonorMB $MinDonorMB -ExcludePath $Path
    if ($donor) {
        $destProj = if ($ProjectRel -eq '.') { $Path } else { Join-Path $Path $ProjectRel }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Copy-Library -Source $donor.library -Destination (Join-Path $destProj 'Library')
        $sw.Stop()
        $seed = [ordered]@{ donor = $donor.library; bytes = $donor.bytes; seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
    }
}

Write-ResultAndExit ([ordered]@{
    action    = 'created'
    path      = $Path
    branch    = $Branch
    baseRef   = $BaseRef
    seeded    = $seed
    nextSteps = @(
        $(if ($seed) { 'open the worktree in Unity once to validate the seeded Library (delta import only)' }
          else { 'no warm donor Library found - first Unity open will be a full import (or configure a local Accelerator first)' })
    )
}) 0
