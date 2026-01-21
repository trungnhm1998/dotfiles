$env:_ZO_DATA_DIR = "$HOME\ZoxideData"
# $env:EDITOR = "code --wait"
# $env:VISUAL = "nvim"
# $poshThemesDir = "$(scoop prefix oh-my-posh)\themes"
# $randomTheme = "clean-detailed.omp.json", "spaceship.omp.json" | Get-Random
# oh-my-posh init pwsh --config  $poshThemesDir\$randomTheme | Invoke-Expression

Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSReadLine
Import-Module CompletionPredictor # Install-Module CompletionPredictor -Scope CurrentUser
Import-Module PSFzf # Install-Module -Name PSFzf -Scope CurrentUser -Forcef
Set-PSReadLineOption -EditMode vi
# Ovrride vi mode ctrl r
Set-PsFzfOption -PSReadlineChordProvider "ctrl+f"
Set-PsFzfOption -PSReadlineChordReverseHistory "ctrl+r"

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -ViModeIndicator Cursor
# F2: enter screen capture/selection mode (scroll + select + Enter to copy)
Set-PSReadLineKeyHandler -Key F2 -Function CaptureScreen
# Vi-mode friendly copy/paste on Space+y / Space+p in command mode
Set-PSReadLineKeyHandler -Key 'y' -Function Copy  -ViMode Command
Set-PSReadLineKeyHandler -Key 'p' -Function Paste -ViMode Command

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}


# Yazi
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}


# --- eza ---
function ls { eza --icons $args }
function l { eza --icons $args }
function ll { eza -lg --icons $args }
function la { eza -lag --icons $args }
function lt { eza -lTg --icons $args }
function lt1 { eza -lTg --level=1 --icons $args }
function lt2 { eza -lTg --level=2 --icons $args }
function lt3 { eza -lTg --level=3 --icons $args }
function lta { eza -lTag --icons $args }
function lta1 { eza -lTag --level=1 --icons $args }
function lta2 { eza -lTag --level=2 --icons $args }
function lta3 { eza -lTag --level=3 --icons $args }

Invoke-Expression (&starship init powershell)
# integrate with wezterm because I use starship
$prompt = ""
function Invoke-Starship-PreCommand {
    $current_location = $executionContext.SessionState.Path.CurrentLocation
    if ($current_location.Provider.Name -eq "FileSystem") {
        $ansi_escape = [char]27
        $provider_path = $current_location.ProviderPath -replace "\\", "/"
        $prompt = "$ansi_escape]7;file://${env:COMPUTERNAME}/${provider_path}$ansi_escape\"
    }
    $host.ui.Write($prompt)
}

# =============================================================================
#
# Utility functions for zoxide.
#

# Call zoxide binary, returning the output as UTF-8.
function global:__zoxide_bin {
    $encoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
        $result = zoxide @args
        return $result
    } finally {
        [Console]::OutputEncoding = $encoding
    }
}

# pwd based on zoxide's format.
function global:__zoxide_pwd {
    $cwd = Get-Location
    if ($cwd.Provider.Name -eq "FileSystem") {
        $cwd.ProviderPath
    }
}

# cd + custom logic based on the value of _ZO_ECHO.
function global:__zoxide_cd($dir, $literal) {
    $dir = if ($literal) {
        Set-Location -LiteralPath $dir -Passthru -ErrorAction Stop
    } else {
        if ($dir -eq '-' -and ($PSVersionTable.PSVersion -lt 6.1)) {
            Write-Error "cd - is not supported below PowerShell 6.1. Please upgrade your version of PowerShell."
        }
        elseif ($dir -eq '+' -and ($PSVersionTable.PSVersion -lt 6.2)) {
            Write-Error "cd + is not supported below PowerShell 6.2. Please upgrade your version of PowerShell."
        }
        else {
            Set-Location -Path $dir -Passthru -ErrorAction Stop
        }
    }
}

# =============================================================================
#
# Hook configuration for zoxide.
#

# Hook to add new entries to the database.
$global:__zoxide_oldpwd = __zoxide_pwd
function global:__zoxide_hook {
    $result = __zoxide_pwd
    if ($result -ne $global:__zoxide_oldpwd) {
        if ($null -ne $result) {
            zoxide add "--" $result
        }
        $global:__zoxide_oldpwd = $result
    }
}

# Initialize hook.
$global:__zoxide_hooked = (Get-Variable __zoxide_hooked -ErrorAction Ignore -ValueOnly)
if ($global:__zoxide_hooked -ne 1) {
    $global:__zoxide_hooked = 1
    $global:__zoxide_prompt_old = $function:prompt

    function global:prompt {
        if ($null -ne $__zoxide_prompt_old) {
            & $__zoxide_prompt_old
        }
        $null = __zoxide_hook
    }
}

# =============================================================================
#
# When using zoxide with --no-cmd, alias these internal functions as desired.
#

# Jump to a directory using only keywords.
function global:__zoxide_z {
    if ($args.Length -eq 0) {
        __zoxide_cd ~ $true
    }
    elseif ($args.Length -eq 1 -and ($args[0] -eq '-' -or $args[0] -eq '+')) {
        __zoxide_cd $args[0] $false
    }
    elseif ($args.Length -eq 1 -and (Test-Path -PathType Container -LiteralPath $args[0])) {
        __zoxide_cd $args[0] $true
    }
    elseif ($args.Length -eq 1 -and (Test-Path -PathType Container -Path $args[0] )) {
        __zoxide_cd $args[0] $false
    }
    else {
        $result = __zoxide_pwd
        if ($null -ne $result) {
            $result = __zoxide_bin query --exclude $result "--" @args
        }
        else {
            $result = __zoxide_bin query "--" @args
        }
        if ($LASTEXITCODE -eq 0) {
            __zoxide_cd $result $true
        }
    }
}

# Jump to a directory using interactive search.
function global:__zoxide_zi {
    $result = __zoxide_bin query -i "--" @args
    if ($LASTEXITCODE -eq 0) {
        __zoxide_cd $result $true
    }
}

# =============================================================================
#
# Commands for zoxide. Disable these using --no-cmd.
#

Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force

# Alias for zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

