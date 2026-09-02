BeforeAll {
    . "$PSScriptRoot\profile-elevated.ps1"
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
    It 'rejects invalid svc lines (trust boundary)' {
        $req = Get-ElevatedRequest -Lines @('svc=DoSvc=stop', 'evil=rm', 'svc=; rm -rf /') -AgeSeconds 1
        $req.Services['DoSvc']     | Should -Be 'stop'
        $req.ContainsKey('evil')   | Should -Be $false
    }
    It 'returns null for svc-only requests if none are whitelisted' {
        Get-ElevatedRequest -Lines @('svc=BadService=stop') -AgeSeconds 1 | Should -BeNullOrEmpty
    }
    It 'still parses vdisp' {
        (Get-ElevatedRequest -Lines @('vdisp=on') -AgeSeconds 1).vdisp | Should -Be 'on'
    }
    It 'rejects invalid vdisp values (trust boundary)' {
        $r = Get-ElevatedRequest -Lines @('svc=DoSvc=stop', 'vdisp=; rm -rf /') -AgeSeconds 1
        $r.Services['DoSvc']      | Should -Be 'stop'
        $r.ContainsKey('vdisp')   | Should -Be $false
    }
    It 'ignores legacy vpn= and hv= lines' {
        $req = Get-ElevatedRequest -Lines @('vpn=stop', 'hv=off') -AgeSeconds 1
        $req | Should -BeNullOrEmpty
    }
    It 'drops stale requests' {
        Get-ElevatedRequest -Lines @('svc=DoSvc=stop') -AgeSeconds 61 | Should -BeNullOrEmpty
    }
    It 'returns null for empty request' {
        Get-ElevatedRequest -Lines @() -AgeSeconds 1 | Should -BeNullOrEmpty
    }
}

Describe 'Stop-ServiceBounded' {
    It 'short-circuits if service is already stopped' {
        $LogPath = Join-Path $TestDrive 'elevated.log'
        Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } }
        Mock Stop-Service {}
        Stop-ServiceBounded -Name 'TestService'
        Should -Invoke Stop-Service -Times 0 -Exactly
    }
    It 'logs a warning if service stops timeout' {
        $LogPath = Join-Path $TestDrive 'elevated.log'
        $fakeService = [pscustomobject]@{ Status = 'Running' } |
            Add-Member -MemberType ScriptMethod -Name WaitForStatus -Value {
                throw [System.ServiceProcess.TimeoutException]::new('timeout')
            } -PassThru
        Mock Get-Service { $fakeService }
        Mock Stop-Service {}
        Stop-ServiceBounded -Name 'TestService' -TimeoutSec 20
        Should -Invoke Stop-Service -Times 1 -Exactly
        Get-Content $LogPath | Should -Match 'WARN svc TestService still not Stopped after 20s'
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
