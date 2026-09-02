BeforeAll {
    . "$PSScriptRoot\profile-toggle.ps1"    # dot-source: loads functions + $Apps, skips main (guard)
}

Describe '$Apps schema' {
    It 'has only work|gaming profiles and non-empty names' {
        foreach ($a in $Apps) {
            $a.Name    | Should -Not -BeNullOrEmpty
            $a.Profile | Should -BeIn @('work', 'gaming')
        }
    }
    It 'every app is either Custom or Procs+Start' {
        foreach ($a in $Apps) {
            if ($a.Custom) {
                $a.Custom.Kill  | Should -Not -BeNullOrEmpty
                $a.Custom.Start | Should -Not -BeNullOrEmpty
            } else {
                $a.Procs | Should -Not -BeNullOrEmpty
                $a.Start | Should -Not -BeNullOrEmpty
            }
        }
    }
    It 'contains the agreed roster' {
        $names = $Apps | ForEach-Object { $_.Name }
        foreach ($n in 'kanata','komorebi','Docker','Slack','PowerToys','GoogleDrive',
                       'OpenVPN','Tailscale','PhoneLink','KDEConnect','Deskflow',
                       'Steam','ExitLag','Discord') { $names | Should -Contain $n }
    }
    It 'every Custom app has a Probe' {
        foreach ($a in ($Apps | Where-Object Custom)) {
            $a.Custom.Probe | Should -Not -BeNullOrEmpty -Because "$($a.Name) needs a was-it-running probe"
        }
    }
}

Describe 'Get-ProfileActions' {
    It 'gaming direction kills every work app and starts every gaming app' {
        $plan = Get-ProfileActions -Direction 'gaming'
        ($plan.Kill  | ForEach-Object Profile) | Should -Not -Contain 'gaming'
        ($plan.Start | ForEach-Object Profile) | Should -Not -Contain 'work'
        ($plan.Kill).Count  | Should -Be (@($Apps | Where-Object Profile -eq 'work')).Count
        ($plan.Start).Count | Should -Be (@($Apps | Where-Object Profile -eq 'gaming')).Count
    }
    It 'work direction is the inverse' {
        $plan = Get-ProfileActions -Direction 'work'
        ($plan.Kill  | ForEach-Object Profile) | Should -Not -Contain 'work'
        ($plan.Start | ForEach-Object Profile) | Should -Not -Contain 'gaming'
    }
    It 'kills kanata first and Docker last (KillOrder)' {
        $kill = (Get-ProfileActions -Direction 'gaming').Kill
        $kill[0].Name  | Should -Be 'kanata'
        $kill[-1].Name | Should -Be 'Docker'
    }
    It 'starts Docker first on the work side (StartOrder)' {
        (Get-ProfileActions -Direction 'work').Start[0].Name | Should -Be 'Docker'
    }
}

Describe 'New-ProfileSnapshot' {
    BeforeAll {
        $script:snap = New-ProfileSnapshot `
            -AppStates @{ Slack = $true; Docker = $false; Steam = $false } `
            -ServiceStates @{ agent_ovpnconnect = 'Running'; DoSvc = 'Stopped'; WinDefend = 'Running' } `
            -PowerScheme '867b47bb-313a-417e-8919-e01e14288ea3' `
            -VirtualDisplaysEnabled $true -BootTime '2026-09-02T07:20:11.0000000+07:00'
    }
    It 'has schemaVersion 1 and the given boot time' {
        $snap.schemaVersion | Should -Be 1
        $snap.bootTime      | Should -Be '2026-09-02T07:20:11.0000000+07:00'
    }
    It 'keeps only managed services' {
        $snap.services.Keys | Should -Not -Contain 'WinDefend'
        $snap.services['agent_ovpnconnect'] | Should -Be 'Running'
        $snap.services['DoSvc']             | Should -Be 'Stopped'
    }
    It 'round-trips through JSON' {
        $back = $snap | ConvertTo-Json -Depth 4 | ConvertFrom-Json -AsHashtable
        $back.apps['Slack']            | Should -BeTrue
        $back.apps['Docker']           | Should -BeFalse
        $back.powerScheme              | Should -Be $snap.powerScheme
        $back.virtualDisplaysEnabled   | Should -BeTrue
        $back.services['DoSvc']        | Should -Be 'Stopped'
    }
}

Describe 'Get-ElevatedRequestLines' {
    It 'gaming stops every managed service and disables virtual displays' {
        (Get-ElevatedRequestLines -Direction 'gaming') | Should -Be @(
            'svc=agent_ovpnconnect=stop', 'svc=ovpnhelper_service=stop', 'svc=DoSvc=stop', 'vdisp=off')
    }
    It 'work starts every managed service and enables virtual displays' {
        (Get-ElevatedRequestLines -Direction 'work') | Should -Be @(
            'svc=agent_ovpnconnect=start', 'svc=ovpnhelper_service=start', 'svc=DoSvc=start', 'vdisp=on')
    }
    It 'never emits vpn= or hv= lines' {
        foreach ($d in 'gaming', 'work') {
            (Get-ElevatedRequestLines -Direction $d) -match '^(vpn|hv)=' | Should -BeNullOrEmpty
        }
    }
}

Describe 'ConvertTo-ProfileName' {
    It 'maps gaming to gaming'            { ConvertTo-ProfileName -Raw "gaming`n"  | Should -Be 'gaming' }
    It 'maps anything else to work'       { ConvertTo-ProfileName -Raw 'garbage'   | Should -Be 'work' }
    It 'maps empty/null to work'          { ConvertTo-ProfileName -Raw ''          | Should -Be 'work' }
}

Describe 'Get-RestoreActions' {
    BeforeAll {
        # Before the game: Slack + kanata + Discord were up; Docker, Steam, ExitLag down.
        $script:snap = @{
            apps = @{ kanata = $true; komorebi = $false; PowerToys = $false; Slack = $true
                      GoogleDrive = $false; PhoneLink = $false; KDEConnect = $false; Deskflow = $false
                      Tailscale = $false; OpenVPN = $false; Docker = $false
                      Steam = $false; ExitLag = $false; Discord = $true }
            services = @{ agent_ovpnconnect = 'Running'; ovpnhelper_service = 'Running'; DoSvc = 'Stopped' }
            powerScheme = '867b47bb-313a-417e-8919-e01e14288ea3'
            virtualDisplaysEnabled = $true
        }
        $script:plan = Get-RestoreActions -Snapshot $snap
    }
    It 'kills only gaming apps that were not running before' {
        ($plan.Kill | ForEach-Object Name) | Should -Be @('Steam', 'ExitLag')
    }
    It 'starts only work apps that were running before, kanata before Slack' {
        ($plan.Start | ForEach-Object Name) | Should -Be @('kanata', 'Slack')
    }
    It 'starts only services that were Running' {
        $plan.Elevated | Should -Contain 'svc=agent_ovpnconnect=start'
        $plan.Elevated | Should -Contain 'svc=ovpnhelper_service=start'
        $plan.Elevated | Should -Not -Contain 'svc=DoSvc=start'
    }
    It 'sends vdisp=on only when virtual displays were enabled' {
        $plan.Elevated | Should -Contain 'vdisp=on'
        $off = Get-RestoreActions -Snapshot (@{ apps = $snap.apps; services = $snap.services; powerScheme = 'x'; virtualDisplaysEnabled = $false })
        $off.Elevated | Should -Not -Contain 'vdisp=on'
    }
    It 'carries the power scheme' {
        $plan.PowerScheme | Should -Be '867b47bb-313a-417e-8919-e01e14288ea3'
    }
    It 'puts Docker first when it was running' {
        $s2 = @{ apps = @{ Docker = $true; Slack = $true; Steam = $true; ExitLag = $true; Discord = $true }
                 services = @{}; powerScheme = 'x'; virtualDisplaysEnabled = $false }
        ((Get-RestoreActions -Snapshot $s2).Start | ForEach-Object Name)[0] | Should -Be 'Docker'
    }
}

Describe 'Get-EnterDecision' {
    It 'enters when there is no snapshot'                 { Get-EnterDecision -SnapshotExists $false -Marker 'work'   | Should -Be 'enter' }
    It 'no-ops when already gaming'                       { Get-EnterDecision -SnapshotExists $true  -Marker 'gaming' | Should -Be 'noop' }
    It 'restores a stale snapshot first when marker=work' { Get-EnterDecision -SnapshotExists $true  -Marker 'work'   | Should -Be 'restore-then-enter' }
}
