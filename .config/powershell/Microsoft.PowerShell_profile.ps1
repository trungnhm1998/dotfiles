$env:_ZO_DATA_DIR = "$HOME\ZoxideData"
$env:EDITOR = "nvim" # so can I press V and open nvim to edit commands
$env:VISUAL = "nvim"

# https://github.com/janikvonrotz/awesome-powershell
Import-Module posh-git # Install-Module posh-git -Scope CurrentUser -Force
Import-Module Terminal-Icons # Install-Module -Name Terminal-Icons -Repository PSGallery
Import-Module PSReadLine # Install-Module PSReadLine -Repository PSGallery -Scope CurrentUser -AllowPrerelease -Force
Import-Module CompletionPredictor # Install-Module CompletionPredictor -Scope CurrentUser
Import-Module PSFzf # Install-Module -Name PSFzf -Scope CurrentUser -Forcef

$env:FZF_DEFAULT_OPTS="--height 50% --layout reverse --border top --inline-info --color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 --color=selected-bg:#51576D --color=border:#737994,label:#C6D0F5"

# Ovrride vi mode ctrl r
Set-PsFzfOption -PSReadlineChordProvider "ctrl+f"
Set-PsFzfOption -PSReadlineChordReverseHistory "ctrl+r"

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

# Alias for zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineOption -EditMode vi -ViModeIndicator Cursor -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView

function claude-mem { & "bun" "C:\Users\mint\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" $args }
