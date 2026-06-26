BeforeAll {
    $env:KOMOREBI_CONFIG_HOME = 'C:\fake\config'    # deterministic config path for the assertion
    . "$PSScriptRoot\wm-toggle.ps1"                  # dot-source: loads functions, skips main (see guard)
}

Describe 'Get-WmToggleAction' {
    It 'tears down (stop --ahk --masir) when komorebi is running' {
        $a = Get-WmToggleAction -Running $true
        $a.Verb            | Should -Be 'stop'
        ($a.Args -join ' ') | Should -Be 'stop --ahk --masir'
    }

    It 'brings up (start --config <cfg> --ahk --masir) when komorebi is not running' {
        $a = Get-WmToggleAction -Running $false
        $a.Verb            | Should -Be 'start'
        ($a.Args -join ' ') | Should -Be 'start --config C:\fake\config\komorebi.json --ahk --masir'
    }
}
