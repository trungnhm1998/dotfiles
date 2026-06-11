# _lib.ps1 - shared helpers for unity-worktree-setup scripts. Dot-source only.
Set-StrictMode -Version Latest

function Get-RepoRoot {
    param([string]$Start = (Get-Location).Path)
    $root = git -C $Start rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) { return $null }
    return (Resolve-Path $root).Path
}

# All worktrees of the repo; first entry is the main checkout.
function Get-Worktrees {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $lines = git -C $RepoRoot worktree list --porcelain
    $wts = [System.Collections.Generic.List[object]]::new()
    $cur = $null
    foreach ($l in $lines) {
        if ($l -like 'worktree *') {
            if ($cur) { $wts.Add([pscustomobject]$cur) }
            $cur = [ordered]@{ path = $l.Substring(9); head = $null; branch = $null; detached = $false }
        }
        elseif ($null -eq $cur) { continue }
        elseif ($l -like 'HEAD *')   { $cur.head = $l.Substring(5) }
        elseif ($l -like 'branch *') { $cur.branch = ($l.Substring(7) -replace '^refs/heads/', '') }
        elseif ($l -eq 'detached')   { $cur.detached = $true }
    }
    if ($cur) { $wts.Add([pscustomobject]$cur) }
    return ,$wts
}

# Unity project dirs (relative to checkout root) found via tracked ProjectVersion.txt.
function Get-UnityProjectRels {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $files = @(git -C $RepoRoot ls-files '*ProjectSettings/ProjectVersion.txt')
    $rels = foreach ($f in $files) {
        $d = Split-Path (Split-Path $f -Parent) -Parent
        if ([string]::IsNullOrEmpty($d)) { '.' } else { $d }
    }
    return ,@($rels)
}

function Get-DirSizeBytes {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [int64]0 }
    if ($IsWindows) {
        $out = robocopy $Path 'NUL' /L /E /NFL /NDL /NJH /NP /BYTES /R:0 /W:0 2>$null
        foreach ($line in $out) {
            if ($line -match '^\s*Bytes\s*:\s*(\d+)') { return [int64]$Matches[1] }
        }
        return [int64]-1
    }
    $out = du -sk -- $Path 2>$null
    if ($out -match '^(\d+)') { return [int64]$Matches[1] * 1024 }
    return [int64]-1
}

# Editor running in this project? Unity holds Temp/UnityLockfile while open.
function Test-UnityEditorOpen {
    param([Parameter(Mandatory)][string]$ProjectDir)
    return (Test-Path -LiteralPath (Join-Path $ProjectDir 'Temp/UnityLockfile'))
}

function Get-DefaultBranch {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $ref = git -C $RepoRoot symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $ref) { return ($ref -replace '^origin/', '') }
    foreach ($cand in @('main', 'master', 'develop')) {
        git -C $RepoRoot show-ref --verify --quiet "refs/remotes/origin/$cand" 2>$null
        if ($LASTEXITCODE -eq 0) { return $cand }
    }
    return $null
}

# Rich status for one worktree. ProjectRel: Unity project dir relative to checkout root.
function Get-WorktreeStatus {
    param(
        [Parameter(Mandatory)][object]$Worktree,
        [Parameter(Mandatory)][string]$ProjectRel,
        [string]$DefaultBranch
    )
    $p = $Worktree.path
    $projDir = if ($ProjectRel -eq '.') { $p } else { Join-Path $p $ProjectRel }
    $libDir = Join-Path $projDir 'Library'
    $dirtyCount = @(git -C $p status --porcelain 2>$null).Count
    $merged = $false
    if ($DefaultBranch) {
        git -C $p merge-base --is-ancestor HEAD "origin/$DefaultBranch" 2>$null
        $merged = ($LASTEXITCODE -eq 0)
    }
    $editorOpen = Test-UnityEditorOpen -ProjectDir $projDir
    $libExists = Test-Path -LiteralPath $libDir
    [pscustomobject][ordered]@{
        path        = $p
        branch      = $Worktree.branch
        detached    = $Worktree.detached
        dirtyFiles  = $dirtyCount
        mergedIntoDefault = $merged
        editorOpen  = $editorOpen
        libraryWarm = $libExists
        projectDir  = $projDir
        # safe to point at new work: clean, no editor, and its branch is parked or already merged
        recyclable  = (($dirtyCount -eq 0) -and (-not $editorOpen) -and ($Worktree.detached -or $merged))
    }
}

# Smallest valid warm Library to copy from; skips editor-open checkouts and stubs.
function Select-DonorLibrary {
    param(
        [Parameter(Mandatory)][object[]]$Worktrees,
        [Parameter(Mandatory)][string]$ProjectRel,
        [int]$MinDonorMB = 200,
        [string]$ExcludePath = ''
    )
    $best = $null
    foreach ($wt in $Worktrees) {
        if ($ExcludePath -and ($wt.path -eq $ExcludePath)) { continue }
        $projDir = if ($ProjectRel -eq '.') { $wt.path } else { Join-Path $wt.path $ProjectRel }
        $lib = Join-Path $projDir 'Library'
        if (-not (Test-Path -LiteralPath $lib)) { continue }
        if (Test-UnityEditorOpen -ProjectDir $projDir) { continue }
        $size = Get-DirSizeBytes -Path $lib
        if ($size -lt ($MinDonorMB * 1MB)) { continue }
        if ($null -eq $best -or $size -lt $best.bytes) {
            $best = [pscustomobject]@{ library = $lib; bytes = $size; checkout = $wt.path }
        }
    }
    return $best
}

function Copy-Library {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if ($IsWindows) {
        robocopy $Source $Destination /E /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    } else {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        rsync -a --delete "$Source/" "$Destination/"
        if ($LASTEXITCODE -ne 0) { throw "rsync failed with exit code $LASTEXITCODE" }
    }
}

# Emit result JSON on stdout and exit. All scripts end through this.
function Write-ResultAndExit {
    param([Parameter(Mandatory)][object]$Result, [int]$ExitCode = 0)
    $Result | ConvertTo-Json -Depth 8
    exit $ExitCode
}
