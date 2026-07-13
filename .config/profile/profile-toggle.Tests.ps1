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

Describe 'ConvertTo-ProfileName' {
    It 'maps gaming to gaming'            { ConvertTo-ProfileName -Raw "gaming`n"  | Should -Be 'gaming' }
    It 'maps anything else to work'       { ConvertTo-ProfileName -Raw 'garbage'   | Should -Be 'work' }
    It 'maps empty/null to work'          { ConvertTo-ProfileName -Raw ''          | Should -Be 'work' }
}
