Import-Module -Name Terminal-Icons

Import-Module -Name PSReadLine
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward

#Import-Module -Name PSColors

Invoke-Expression (&starship init powershell)

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

# Alias for zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })
function cd { z $args }

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

