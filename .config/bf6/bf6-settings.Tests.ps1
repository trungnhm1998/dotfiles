BeforeAll {
    . "$PSScriptRoot\bf6-settings.ps1"
}

Describe '$Bf6Targets' {
    It 'holds every key as a string (formatting is load-bearing)' {
        foreach ($k in $Bf6Targets.Keys) {
            $Bf6Targets[$k] | Should -BeOfType [string]
        }
    }
    It 'does not try to automate AmbientOcclusion (mode list, set via menu)' {
        $Bf6Targets.ContainsKey('GstRender.AmbientOcclusion') | Should -Be $false
    }
}

Describe 'Get-ProfsavePatch' {
    It 'rewrites a present key' {
        $out = Get-ProfsavePatch -Lines @('GstRender.MeshQuality 3') `
                                 -Targets @{ 'GstRender.MeshQuality' = '1' }
        $out[0] | Should -Be 'GstRender.MeshQuality 1'
    }
    It 'leaves unrelated lines byte-identical' {
        $lines = @('GstRender.MeshQuality 3', 'GstInput.MouseSensitivity 0.123456', '')
        $out = Get-ProfsavePatch -Lines $lines -Targets @{ 'GstRender.MeshQuality' = '1' }
        $out[1] | Should -Be 'GstInput.MouseSensitivity 0.123456'
        $out[2] | Should -Be ''
        $out.Count | Should -Be 3
    }
    It 'skips an absent key instead of appending it' {
        $out = Get-ProfsavePatch -Lines @('GstRender.MeshQuality 3') `
                                 -Targets @{ 'GstRender.NotARealKey' = '9' }
        $out.Count | Should -Be 1
        ($out -join "`n") | Should -Not -Match 'NotARealKey'
    }
    It 'does not cross-match keys that share a prefix' {
        # GstRender.Resolution must never eat GstRender.ResolutionWidth
        $lines = @('GstRender.ResolutionWidth 3840', 'GstRender.ResolutionHeight 2160')
        $out = Get-ProfsavePatch -Lines $lines -Targets @{ 'GstRender.Resolution' = '999' }
        $out[0] | Should -Be 'GstRender.ResolutionWidth 3840'
        $out[1] | Should -Be 'GstRender.ResolutionHeight 2160'
    }
    It 'is idempotent' {
        $t = @{ 'GstRender.MeshQuality' = '1' }
        $once  = Get-ProfsavePatch -Lines @('GstRender.MeshQuality 3') -Targets $t
        $twice = Get-ProfsavePatch -Lines $once -Targets $t
        ($twice -join "`n") | Should -Be ($once -join "`n")
    }
    It 'preserves float formatting from the targets table' {
        $out = Get-ProfsavePatch -Lines @('GstRender.ResolutionHertz 60.000000') `
                                 -Targets @{ 'GstRender.ResolutionHertz' = '480.000000' }
        $out[0] | Should -Be 'GstRender.ResolutionHertz 480.000000'
    }
}
