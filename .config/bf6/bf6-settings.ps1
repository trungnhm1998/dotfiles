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
# this against the in-game menu on first run BEFORE these values are trusted.
#
# GstRender.AmbientOcclusion is deliberately absent: it is a mode list (Off/SSAO/
# GTAO...), not a quality ladder, so it is set from the menu, not from here.
$Bf6Targets = @{
    'GstRender.ResolutionWidth'       = '1920'
    'GstRender.ResolutionHeight'      = '1080'
    'GstRender.ResolutionHertz'       = '480.000000'
    'GstRender.FullscreenRefreshRate' = '480.000000'
    'GstRender.MeshQuality'           = '1'
    'GstRender.EffectsQuality'        = '0'
    'GstRender.UndergrowthQuality'    = '1'
    'GstRender.TerrainQuality'        = '1'
    'GstRender.PostProcessQuality'    = '0'
    # Hold at 0 so the in-game overlay does not stack on top of the user.cfg
    # PerfOverlay cvars. The requirement is ONE number, not a block.
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

if ($MyInvocation.InvocationName -ne '.') {
    # Main path lands in Task 2.
}
