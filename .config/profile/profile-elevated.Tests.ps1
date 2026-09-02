BeforeAll {
    . "$PSScriptRoot\profile-elevated.ps1"    # dot-source: loads functions, skips main (guard)
}

Describe 'Get-ElevatedRequest' {
    It 'accepts svc stop/start for whitelisted services' {
        $req = Get-ElevatedRequest -Lines @('svc=DoSvc=stop', 'svc=agent_ovpnconnect=start') -AgeSeconds 1
        $req.Services['DoSvc']             | Should -Be 'stop'
        $req.Services['agent_ovpnconnect'] | Should -Be 'start'
    }
    It 'rejects services outside the whitelist' {
        $req = Get-ElevatedRequest -Lines @('svc=WinDefend=stop') -AgeSeconds 1
        $req | Should -BeNullOrEmpty
    }
    It 'rejects verbs other than stop|start' {
        $req = Get-ElevatedRequest -Lines @('svc=DoSvc=disable') -AgeSeconds 1
        $req | Should -BeNullOrEmpty
    }
    It 'still parses vdisp' {
        (Get-ElevatedRequest -Lines @('vdisp=on') -AgeSeconds 1).vdisp | Should -Be 'on'
    }
    It 'ignores legacy vpn= and hv= lines' {
        $req = Get-ElevatedRequest -Lines @('vpn=stop', 'hv=off') -AgeSeconds 1
        $req | Should -BeNullOrEmpty
    }
    It 'drops stale requests' {
        Get-ElevatedRequest -Lines @('svc=DoSvc=stop') -AgeSeconds 61 | Should -BeNullOrEmpty
    }
}

Describe 'Test-VirtualDisplayHwId' {
    It 'matches the virtual adapters' {
        Test-VirtualDisplayHwId -HardwareIds @('ROOT\SudoMaker\SudoVDA') | Should -BeTrue
        Test-VirtualDisplayHwId -HardwareIds @('SuperDisplay\Display')   | Should -BeTrue
    }
    It 'never matches the real GPUs' {
        Test-VirtualDisplayHwId -HardwareIds @('PCI\VEN_10DE&DEV_2C05&SUBSYS_00000000&REV_A1', 'PCI\VEN_10DE&DEV_2C05') | Should -BeFalse
        Test-VirtualDisplayHwId -HardwareIds @('PCI\VEN_8086&DEV_A780&SUBSYS_00000000&REV_04') | Should -BeFalse
    }
}
