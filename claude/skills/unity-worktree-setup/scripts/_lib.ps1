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

function Test-TcpEndpoint { # "host:port" -> $true/$false, or $null if not parseable
    param([string]$Endpoint, [int]$TimeoutMs = 3000)
    if ($Endpoint -notmatch '^(.+):(\d+)$') { return $null }
    $client = [System.Net.Sockets.TcpClient]::new()
    try { return $client.ConnectAsync($Matches[1], [int]$Matches[2]).Wait($TimeoutMs) }
    catch { return $false }
    finally { $client.Dispose() }
}

# Project-level cache server config from ProjectSettings/EditorSettings.asset.
# m_CacheServerMode: 0 = as-preferences (fall back to per-user), 1 = enabled, 2 = disabled.
function Get-ProjectCacheServer {
    param([string]$ProjectDir)
    $r = [ordered]@{ mode = $null; endpoint = $null }
    $es = Join-Path $ProjectDir 'ProjectSettings/EditorSettings.asset'
    if (Test-Path -LiteralPath $es) {
        $t = Get-Content -LiteralPath $es -Raw
        if ($t -match 'm_CacheServerMode:\s*(\d)') { $r.mode = @('as-preferences', 'enabled', 'disabled')[[int]$Matches[1]] }
        if ($t -match 'm_CacheServerEndpoint:\s*(\S+)') { $r.endpoint = $Matches[1] }
    }
    return [pscustomobject]$r
}

# Per-user (EditorPrefs) Accelerator setting. Key names verified from UnityCsReference
# AssetPipelinePreferences.cs: CacheServer2Mode (enum Enabled=0, Disabled=1), CacheServer2IPAddress.
# Windows stores EditorPrefs as hashed registry values (strings = REG_BINARY UTF-8 bytes).
function Get-UserCacheServerPref {
    $r = [ordered]@{ mode = $null; endpoint = $null }
    if ($IsWindows) {
        $out = reg.exe query 'HKCU\Software\Unity Technologies\Unity Editor 5.x' /f CacheServer2 2>$null
        foreach ($line in @($out)) {
            if ($line -match '^\s+CacheServer2Mode_h\d+\s+REG_DWORD\s+0x([0-9a-fA-F]+)') {
                $r.mode = if ([Convert]::ToInt32($Matches[1], 16) -eq 0) { 'enabled' } else { 'disabled' }
            }
            elseif ($line -match '^\s+CacheServer2IPAddress_h\d+\s+REG_BINARY\s+([0-9a-fA-F]+)') {
                $hex = $Matches[1]
                $bytes = [byte[]]::new($hex.Length / 2)
                for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
                $r.endpoint = [Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
            }
            elseif ($line -match '^\s+CacheServer2IPAddress_h\d+\s+REG_SZ\s+(.+)$') {
                $r.endpoint = $Matches[1].Trim()
            }
        }
    }
    elseif ($IsMacOS) {
        $mode = defaults read com.unity3d.UnityEditor5.x CacheServer2Mode 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $mode -and "$mode" -match '^\d') { $r.mode = if ([int]$mode -eq 0) { 'enabled' } else { 'disabled' } }
        $ep = defaults read com.unity3d.UnityEditor5.x CacheServer2IPAddress 2>$null
        if ($LASTEXITCODE -eq 0 -and $ep) { $r.endpoint = "$ep".Trim() }
    }
    return [pscustomobject]$r
}

# First configured Accelerator endpoint (project config beats per-user), with live reachability.
# Returns $null when no endpoint is configured anywhere.
function Get-AcceleratorCandidate {
    param([string]$ProjectDir, [int]$TimeoutMs = 3000)
    $proj = Get-ProjectCacheServer -ProjectDir $ProjectDir
    if ($proj.endpoint) {
        return [pscustomobject]@{ endpoint = $proj.endpoint; source = 'project'; mode = $proj.mode; reachable = (Test-TcpEndpoint -Endpoint $proj.endpoint -TimeoutMs $TimeoutMs) }
    }
    $user = Get-UserCacheServerPref
    if ($user.endpoint) {
        return [pscustomobject]@{ endpoint = $user.endpoint; source = 'user'; mode = $user.mode; reachable = (Test-TcpEndpoint -Endpoint $user.endpoint -TimeoutMs $TimeoutMs) }
    }
    return $null
}

# Emit result JSON on stdout and exit. All scripts end through this.
function Write-ResultAndExit {
    param([Parameter(Mandatory)][object]$Result, [int]$ExitCode = 0)
    $Result | ConvertTo-Json -Depth 8
    exit $ExitCode
}
