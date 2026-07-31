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

Describe 'Get-ElevatedRequest - vdisp' {
    It 'parses vdisp=off and vdisp=on' {
        (Get-ElevatedRequest -Lines @('vdisp=off') -AgeSeconds 1).vdisp | Should -Be 'off'
        (Get-ElevatedRequest -Lines @('vdisp=on')  -AgeSeconds 1).vdisp | Should -Be 'on'
    }
    It 'rejects any other vdisp value (trust boundary)' {
        $r = Get-ElevatedRequest -Lines @('vpn=stop', 'vdisp=; rm -rf /') -AgeSeconds 1
        $r.ContainsKey('vdisp') | Should -Be $false
        $r.vpn | Should -Be 'stop'
    }
    It 'parses vdisp alongside vpn and hv' {
        $r = Get-ElevatedRequest -Lines @('vpn=stop', 'hv=off', 'vdisp=off') -AgeSeconds 1
        $r.vpn   | Should -Be 'stop'
        $r.hv    | Should -Be 'off'
        $r.vdisp | Should -Be 'off'
    }
}

Describe 'Test-VirtualDisplayHwId' {
    It 'matches the SudoMaker virtual adapter' {
        Test-VirtualDisplayHwId -HardwareIds @('root\sudomaker\sudovda') | Should -Be $true
    }
    It 'matches the SuperDisplay virtual adapter (case-insensitively)' {
        Test-VirtualDisplayHwId -HardwareIds @('SuperDisplay\Display') | Should -Be $true
    }
    It 'NEVER matches the real NVIDIA GPU' {
        $nvidia = @(
            'PCI\VEN_10DE&DEV_2C05&SUBSYS_53101462&REV_A1'
            'PCI\VEN_10DE&DEV_2C05&SUBSYS_53101462'
            'PCI\VEN_10DE&DEV_2C05&CC_030000'
            'PCI\VEN_10DE&DEV_2C05&CC_0300'
        )
        Test-VirtualDisplayHwId -HardwareIds $nvidia | Should -Be $false
    }
    It 'NEVER matches the Intel iGPU' {
        $intel = @(
            'PCI\VEN_8086&DEV_A780&SUBSYS_D0001458&REV_04'
            'PCI\VEN_8086&DEV_A780&CC_038000'
        )
        Test-VirtualDisplayHwId -HardwareIds $intel | Should -Be $false
    }
    It 'returns false for empty or null input' {
        Test-VirtualDisplayHwId -HardwareIds @()     | Should -Be $false
        Test-VirtualDisplayHwId -HardwareIds @($null) | Should -Be $false
    }
}
