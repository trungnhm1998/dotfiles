#Requires -Version 5.1
<#
    bf6-settings.ps1 - patch Battlefield 6 graphics settings in PROFSAVE*_profile.

    Why patch instead of symlink: BF6 rewrites this file on every settings change
    and every game patch, and it holds keybinds, loadouts and ~98KB of unrelated
    state. Key-level patching means a patch can clobber the graphics settings and
    one command restores them without touching anything else.

    Design: docs/specs/2026-07-31-bf6-competitive-config-design.md
      (no args)   -> patch the live profile (refuses while bf6.exe is running)
      -Verify     -> print current vs target for every key, write nothing
#>
param(
    [switch]$Verify
)

$SettingsDir = Join-Path $env:USERPROFILE 'Documents\Battlefield 6\settings\steam'

# PROFSAVE key -> desired value. Values are STRINGS because the file's numeric
# formatting matters: some keys are plain ints, some are 6-decimal floats, and
# rewriting one as the other is how you get a setting the game silently ignores.
#
# Quality ladder assumed to be 0=Low 1=Medium 2=High 3=Ultra. Task 7 cross-checks
# this against the in-game menu on first run BEFORE ShadowQuality is trusted; every
# other quality key here is held at its existing value rather than moved.
#
# GstRender.AmbientOcclusion is deliberately absent: it is a mode list (Off/SSAO/
# GTAO...), not a quality ladder, so it is set from the menu, not from here.
$Bf6Targets = @{
    # Display: 1440x1080 (4:3 stretched) @ 480Hz, confirmed by the user 2026-07-31
    # after trying native 1920x1080. The panel runs its FHD 480Hz dual-mode and the
    # GPU scales 1440 -> 1920 horizontally, so the stretch costs no refresh.
    #
    # GstRender.FullscreenRefreshRate is deliberately ABSENT. The game writes the
    # true measured refresh there (observed 480.001007), so any hardcoded value
    # would report as needing a patch forever and overwrite a number the game knows
    # better than we do. ResolutionHertz already pins the intent.
    #
    # GstRender.AspectRatio is also absent: it currently reads 20 and the stretched
    # setup works, but the enum is undocumented and guarding a value we cannot
    # interpret risks reverting a correct future fix.
    'GstRender.ResolutionWidth'       = '1440'
    'GstRender.ResolutionHeight'      = '1080'
    'GstRender.ResolutionHertz'       = '480.000000'
    # VSync was ON (1). It adds input latency and fights Reflex. Highest-value
    # single change found on this machine.
    'GstRender.VSyncMode'             = '0'
    # Quality: already at 0 on the live profile. Held here as guards so a patch
    # or a stray menu click cannot silently raise them again.
    'GstRender.MeshQuality'           = '0'
    'GstRender.EffectsQuality'        = '0'
    'GstRender.UndergrowthQuality'    = '0'
    'GstRender.TerrainQuality'        = '0'
    'GstRender.PostProcessQuality'    = '0'
    # Hold at 0 so the in-game overlay does not stack on the user.cfg PerfOverlay
    # cvars. The requirement is ONE number, not a block.
    'GstRender.PerformanceOverlay'    = '0'
}

function Get-ProfsavePatch {
    # Pure: lines + targets -> patched lines. No file IO, so this is the tested part.
    # Absent keys are skipped, never appended: an absent key usually means the game
    # renamed it in a patch, and appending unknown keys is how configs get corrupted.
    param(
        [string[]]$Lines,
        [Parameter(Mandatory)][hashtable]$Targets
    )
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        $replaced = $false
        foreach ($key in $Targets.Keys) {
            # Trailing \s anchor is what stops GstRender.Resolution from eating
            # GstRender.ResolutionWidth.
            if ($line -match ('^' + [regex]::Escape($key) + '\s')) {
                $out.Add("$key $($Targets[$key])")
                $replaced = $true
                break
            }
        }
        if (-not $replaced) { $out.Add($line) }
    }
    return ,($out.ToArray())
}

function Get-LiveProfsavePath {
    # Newest PROFSAVE*_profile wins. BF6 has shipped several names (PROFSAVE_profile,
    # PROFSAVEbf6mp_profile); the most recently written one is the live multiplayer
    # profile. Returns $null when the dir or the file is missing.
    if (-not (Test-Path $SettingsDir)) { return $null }
    $f = Get-ChildItem -Path $SettingsDir -Filter 'PROFSAVE*_profile' -File -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 1
    if (-not $f) { return $null }
    return $f.FullName
}

function Show-Bf6Verify {
    param([Parameter(Mandatory)][string]$Path)
    $lines = Get-Content -Path $Path
    foreach ($key in ($Bf6Targets.Keys | Sort-Object)) {
        $hit = $lines | Where-Object { $_ -match ('^' + [regex]::Escape($key) + '\s') } | Select-Object -First 1
        if (-not $hit) {
            Write-Host ("  {0,-36} ABSENT (skipped)" -f $key) -ForegroundColor DarkYellow
            continue
        }
        $current = ($hit -split '\s+', 2)[1]
        $want    = $Bf6Targets[$key]
        if ($current -eq $want) {
            Write-Host ("  {0,-36} {1}" -f $key, $current) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-36} {1}  ->  {2}" -f $key, $current, $want) -ForegroundColor Yellow
        }
    }
}

function Invoke-Bf6Patch {
    param([Parameter(Mandatory)][string]$Path)
    # Backup first, and abort if the backup did not land. Losing keybinds and
    # loadouts to a half-written patch is a far worse outcome than not patching.
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Path.bak-$stamp"
    Copy-Item -Path $Path -Destination $backup -ErrorAction Stop
    if (-not (Test-Path $backup)) { throw "backup failed: $backup" }
    Write-Host "Backup  $backup" -ForegroundColor DarkGray

    $lines   = Get-Content -Path $Path
    $patched = Get-ProfsavePatch -Lines $lines -Targets $Bf6Targets
    Set-Content -Path $Path -Value $patched
    Write-Host "Patched $Path" -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    $path = Get-LiveProfsavePath
    if (-not $path) {
        Write-Host "No PROFSAVE*_profile found under $SettingsDir" -ForegroundColor Red
        Write-Host "Launch BF6 once so it writes a profile, then re-run." -ForegroundColor Yellow
        exit 1
    }
    if ($Verify) {
        Write-Host "Live profile: $path" -ForegroundColor Cyan
        Show-Bf6Verify -Path $path
        exit 0
    }
    # BF6 rewrites PROFSAVE wholesale when it exits, which would silently discard
    # everything we just wrote. Refuse rather than produce a patch that evaporates.
    if (Get-Process 'bf6' -ErrorAction SilentlyContinue) {
        Write-Host "BF6 is running. Close it first - it rewrites PROFSAVE on exit and would discard this patch." -ForegroundColor Red
        exit 1
    }
    Invoke-Bf6Patch -Path $path
    Show-Bf6Verify -Path $path
}
