BeforeAll {
    $env:XDG_CONFIG_HOME = 'C:\fake\config'    # deterministic cfg path for the assertion
    . "$PSScriptRoot\kanata-toggle.ps1"        # dot-source: loads functions, skips main (see guard)
}

Describe 'Get-KanataToggleAction' {
    It 'stops when kanata is running' {
        $a = Get-KanataToggleAction -Running $true
        $a.Verb | Should -Be 'stop'
    }

    It 'starts with the win.kbd cfg when kanata is not running' {
        $a = Get-KanataToggleAction -Running $false
        $a.Verb | Should -Be 'start'
        $a.Cfg  | Should -Be 'C:\fake\config\kanata\kanata.win.kbd'
    }
}

Describe 'Invoke-KanataToggle' {
    It 'launches kanata with --no-wait so a bad config fails visibly' {
        Mock Test-KanataRunning { $false }
        Mock Start-Process { }
        Mock Add-Content { }

        Invoke-KanataToggle

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -contains '--no-wait'
        }
    }

    It 'still passes the win.kbd config path' {
        Mock Test-KanataRunning { $false }
        Mock Start-Process { }
        Mock Add-Content { }

        Invoke-KanataToggle

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -contains 'C:\fake\config\kanata\kanata.win.kbd'
        }
    }
}
