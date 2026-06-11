# preflight.ps1 - read-only audit of a Unity repo before worktree operations.
# Exit: 0 ok, 2 blockers found. Output: JSON on stdout.
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [int]$TcpTimeoutMs = 3000
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not $RepoRoot) { $RepoRoot = Get-RepoRoot }
if (-not $RepoRoot) { Write-ResultAndExit @{ blockers = @('not inside a git repository') } 2 }

$blockers = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$projectRels = Get-UnityProjectRels -RepoRoot $RepoRoot
if ($projectRels.Count -eq 0) { $blockers.Add('no tracked ProjectSettings/ProjectVersion.txt found - not a Unity repo?') }

$worktrees = Get-Worktrees -RepoRoot $RepoRoot
$defaultBranch = Get-DefaultBranch -RepoRoot $RepoRoot
if (-not $defaultBranch) { $warnings.Add('could not detect default branch from origin') }

# tracked symlinks break silently on Windows without core.symlinks + Developer Mode
$symlinkCount = @(git -C $RepoRoot ls-files -s | Select-String '^120000').Count
$coreSymlinks = git -C $RepoRoot config --get core.symlinks 2>$null
if ($symlinkCount -gt 0 -and $IsWindows -and $coreSymlinks -ne 'true') {
    $blockers.Add("$symlinkCount tracked symlinks but core.symlinks!=true on Windows - worktree checkouts would materialize them as text files")
}

$projects = foreach ($rel in $projectRels) {
    $projDir = if ($rel -eq '.') { $RepoRoot } else { Join-Path $RepoRoot $rel }

    $versionFile = Join-Path $projDir 'ProjectSettings/ProjectVersion.txt'
    $unityVersion = ((Get-Content -LiteralPath $versionFile -TotalCount 1) -replace 'm_EditorVersion:\s*', '').Trim()

    # Library MUST be ignored or a worktree checkout/commit could include gigabytes.
    # Probe a file INSIDE Library: dir patterns like '/[Ll]ibrary/' + negation lines make
    # check-ignore on the bare directory return "not ignored" even when contents are.
    $probe = if ($rel -eq '.') { 'Library/__wtprobe__' } else { "$rel/Library/__wtprobe__" }
    git -C $RepoRoot check-ignore -q $probe 2>$null
    $libIgnored = ($LASTEXITCODE -eq 0)
    if (-not $libIgnored) { $blockers.Add("$rel/Library is NOT gitignored") }

    # file: package deps that escape the repo break in worktrees
    $manifestRisks = @()
    $manifest = Join-Path $projDir 'Packages/manifest.json'
    if (Test-Path -LiteralPath $manifest) {
        $matches_ = [regex]::Matches((Get-Content -LiteralPath $manifest -Raw), '"file:([^"]+)"')
        foreach ($m in $matches_) {
            $dep = $m.Groups[1].Value
            if ($dep -match '^([A-Za-z]:|/)') { $manifestRisks += "absolute: $dep"; continue }
            $resolved = [IO.Path]::GetFullPath((Join-Path (Join-Path $projDir 'Packages') $dep))
            if (-not $resolved.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                $manifestRisks += "escapes repo: $dep"
            }
        }
        if ($manifestRisks.Count -gt 0) { $warnings.Add("$rel/Packages/manifest.json has file: deps that will not resolve in a worktree: $($manifestRisks -join '; ')") }
    }

    # cache server (Accelerator) config + live reachability
    $cache = [ordered]@{ mode = $null; endpoint = $null; reachable = $null }
    $editorSettings = Join-Path $projDir 'ProjectSettings/EditorSettings.asset'
    if (Test-Path -LiteralPath $editorSettings) {
        $es = Get-Content -LiteralPath $editorSettings -Raw
        if ($es -match 'm_CacheServerMode:\s*(\d)') { $cache.mode = @('as-preferences', 'enabled', 'disabled')[[int]$Matches[1]] }
        if ($es -match 'm_CacheServerEndpoint:\s*(\S+)') { $cache.endpoint = $Matches[1] }
        if ($cache.endpoint -and $cache.mode -ne 'disabled' -and $cache.endpoint -match '^(.+):(\d+)$') {
            $client = [System.Net.Sockets.TcpClient]::new()
            try {
                $cache.reachable = $client.ConnectAsync($Matches[1], [int]$Matches[2]).Wait($TcpTimeoutMs)
            } catch { $cache.reachable = $false } finally { $client.Dispose() }
            if ($cache.reachable -eq $false) { $warnings.Add("$rel cache server $($cache.endpoint) is configured but unreachable - cold imports will be full local recomputes") }
        }
    }

    $lib = Join-Path $projDir 'Library'
    [pscustomobject][ordered]@{
        projectRel     = $rel
        unityVersion   = $unityVersion
        libraryIgnored = $libIgnored
        libraryExists  = (Test-Path -LiteralPath $lib)
        libraryBytes   = (Get-DirSizeBytes -Path $lib)
        editorOpen     = (Test-UnityEditorOpen -ProjectDir $projDir)
        cacheServer    = $cache
        manifestRisks  = @($manifestRisks)
    }
}

$freeDisk = [int64](Get-PSDrive -Name ((Get-Item $RepoRoot).PSDrive.Name)).Free
$primaryLib = [int64](@($projects | ForEach-Object { $_.libraryBytes }) | Measure-Object -Maximum).Maximum
if ($primaryLib -gt 0 -and $freeDisk -lt ($primaryLib * 2)) {
    $warnings.Add('free disk is less than 2x the Library size - each seeded worktree costs one Library copy')
}

$result = [ordered]@{
    repoRoot      = $RepoRoot
    defaultBranch = $defaultBranch
    projects      = @($projects)
    worktrees     = @($worktrees | ForEach-Object { $_.path })
    trackedSymlinks = $symlinkCount
    freeDiskBytes = $freeDisk
    blockers      = @($blockers)
    warnings      = @($warnings)
}
Write-ResultAndExit $result $(if ($blockers.Count -gt 0) { 2 } else { 0 })
