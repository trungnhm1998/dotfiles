BeforeAll {
    . "$PSScriptRoot\profile-elevated.ps1"
}

Describe 'Get-ElevatedRequest' {
    It 'parses valid vpn+hv lines' {
        $r = Get-ElevatedRequest -Lines @('vpn=stop', 'hv=off') -AgeSeconds 1
        $r.vpn | Should -Be 'stop'
        $r.hv  | Should -Be 'off'
    }
    It 'rejects stale requests (>60s)' {
        Get-ElevatedRequest -Lines @('vpn=stop') -AgeSeconds 61 | Should -Be $null
    }
    It 'ignores unknown keys and invalid values (trust boundary)' {
        $r = Get-ElevatedRequest -Lines @('vpn=stop', 'evil=rm', 'hv=nonsense') -AgeSeconds 1
        $r.vpn            | Should -Be 'stop'
        $r.ContainsKey('hv')   | Should -Be $false
        $r.ContainsKey('evil') | Should -Be $false
    }
    It 'returns null for an empty request' {
        Get-ElevatedRequest -Lines @() -AgeSeconds 1 | Should -Be $null
    }
}
