#Requires -Version 7.0

<#
.SYNOPSIS
    Windows dotfiles deployment script
.DESCRIPTION
    Deploys dotfiles, installs packages via winget, and sets up development environment
.PARAMETER SkipPackages
    Skip winget package installation
.PARAMETER SkipSymlinks
    Skip symlink creation
.PARAMETER Force
    Overwrite existing configs without prompting
.PARAMETER DryRun
    Show what would be done without executing
.PARAMETER SkipFonts
    Skip Powerline fonts installation
.NOTES
    Requires Administrator privileges for creating symbolic links
#>

param(
    [switch]$SkipPackages,
    [switch]$SkipSymlinks,
    [switch]$SkipFonts,
    [switch]$Force,
    [switch]$DryRun
)

# =============================================================================
# Configuration
# =============================================================================

$dotfilesRoot = $PSScriptRoot

$packages = @(
    # Core Development Tools
    @{ Id = "Neovim.Neovim"; Name = "Neovim" }
    @{ Id = "OpenJS.NodeJS.LTS"; Name = "Node.js LTS" }
    @{ Id = "Git.Git"; Name = "Git" }

    # CLI Utilities
    @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep" }
    @{ Id = "junegunn.fzf"; Name = "fzf" }
    @{ Id = "sharkdp.fd"; Name = "fd" }
    @{ Id = "eza-community.eza"; Name = "eza" }
    @{ Id = "jesseduffield.lazygit"; Name = "lazygit" }
    @{ Id = "Starship.Starship"; Name = "Starship" }
    @{ Id = "sxyazi.yazi"; Name = "yazi" }
    @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" }
    @{ Id = "sharkdp.bat"; Name = "bat" }
    @{ Id = "jqlang.jq"; Name = "jq" }
    @{ Id = "GitHub.cli"; Name = "GitHub CLI" }

    # Windows-Specific Tools
    @{ Id = "LGUG2Z.komorebi"; Name = "Komorebi" }
    @{ Id = "AutoHotkey.AutoHotkey"; Name = "AutoHotkey" }
    @{ Id = "wez.wezterm"; Name = "Wezterm" }
    @{ Id = "AmN.yasb"; Name = "YASB" }

    # Fonts
    @{ Id = "DEVCOM.JetBrainsMonoNerdFont"; Name = "JetBrainsMono Nerd Font" }
)

$powershellModules = @(
    "posh-git"
    "Terminal-Icons"
    "PSReadLine"
    "BurntToast"   # clickable Claude toasts (claude-notify.ps1 emit mode)
)

$symlinks = @(
    # Directory symlinks
    @{
        Source      = "$dotfilesRoot\.config\komorebi"
        Target      = "$HOME\.config\komorebi"
        IsDirectory = $true
        Description = "Komorebi tiling window manager"
    }
    @{
        Source      = "$dotfilesRoot\.config\kanata"
        Target      = "$HOME\.config\kanata"
        IsDirectory = $true
        Description = "Kanata keyboard remapper (Windows 60%)"
    }
    @{
        Source      = "$dotfilesRoot\.config\yasb"
        Target      = "$HOME\.config\yasb"
        IsDirectory = $true
        Description = "YASB status bar (Windows)"
    }
    @{
        Source      = "$dotfilesRoot\.config\nvim"
        Target      = "$HOME\.config\nvim"
        IsDirectory = $true
        Description = "Neovim configuration"
    }
    @{
        Source      = "$dotfilesRoot\.config\wezterm"
        Target      = "$HOME\.config\wezterm"
        IsDirectory = $true
        Description = "Wezterm terminal"
    }
    @{
        Source      = "$dotfilesRoot\.config\zellij"
        Target      = "$HOME\.config\zellij"
        IsDirectory = $true
        Description = "Zellij multiplexer (Windows)"
    }
    @{
        Source      = "$dotfilesRoot\.config\psmux"
        Target      = "$HOME\.config\psmux"
        IsDirectory = $true
        Description = "psmux (native-Windows tmux)"
    }
    @{
        Source      = "$dotfilesRoot\.config\yazi"
        Target      = "$env:APPDATA\yazi\config"
        IsDirectory = $true
        Description = "Yazi file manager"
    }
    @{
        Source      = "$dotfilesRoot\.config\lazygit"
        Target      = "$env:APPDATA\lazygit"
        IsDirectory = $true
        Description = "Lazygit"
    }
    @{
        Source      = "$dotfilesRoot\.config\bat"
        Target      = "$HOME\.config\bat"
        IsDirectory = $true
        Description = "Bat a Cat replacement"
    }

    # File symlinks
    @{
        Source      = "$dotfilesRoot\.config\starship.toml"
        Target      = "$HOME\.config\starship.toml"
        IsDirectory = $false
        Description = "Starship prompt"
    }
    @{
        Source      = "$dotfilesRoot\.config\ccstatusline\settings.json"
        Target      = "$HOME\.config\ccstatusline\settings.json"
        IsDirectory = $false
        Description = "ccstatusline statusline config"
    }
    @{
        Source      = "$dotfilesRoot\.config\powershell\Microsoft.PowerShell_profile.ps1"
        Target      = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
        IsDirectory = $false
        Description = "PowerShell profile"
    }
    @{
        Source      = "$dotfilesRoot\.ideavimrc"
        Target      = "$HOME\.ideavimrc"
        IsDirectory = $false
        Description = "IdeaVim configuration"
    }
    @{
        Source      = "$dotfilesRoot\zed\settings.windows.json"
        Target      = "$env:APPDATA\Zed\settings.json"
        IsDirectory = $false
        Description = "Zed editor settings"
    }
    @{
        Source      = "$dotfilesRoot\zed\keymap.json"
        Target      = "$env:APPDATA\Zed\keymap.json"
        IsDirectory = $false
        Description = "Zed editor keybindings"
    }
    @{
        Source      = "$dotfilesRoot\.config\windows-terminal\catppuccin-frappe.json"
        Target      = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\catppuccin-frappe.json"
        IsDirectory = $false
        Description = "Windows Terminal Catppuccin Frappe color scheme (stable + Preview)"
    }

    # --- Global agent instructions: one canonical file (claude\AGENTS.md) ---
    # Single source of truth shared by Claude Code, Codex, and opencode. Claude Code
    # reads it under the CLAUDE.md name; Codex/opencode read it as AGENTS.md (see below).
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.claude\CLAUDE.md"
        IsDirectory = $false
        Description = "Claude Code global instructions (canonical claude\AGENTS.md)"
    }
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.claude\AGENTS.md"
        IsDirectory = $false
        Description = "Global agent instructions (~\.claude\AGENTS.md)"
    }

    # --- Claude Code (other authored config) ---
    @{
        Source      = "$dotfilesRoot\claude\settings.json"
        Target      = "$HOME\.claude\settings.json"
        IsDirectory = $false
        Description = "Claude Code settings"
    }
    @{
        Source      = "$dotfilesRoot\claude\agents"
        Target      = "$HOME\.claude\agents"
        IsDirectory = $true
        Description = "Claude Code agents"
    }
    @{
        Source      = "$dotfilesRoot\claude\commands"
        Target      = "$HOME\.claude\commands"
        IsDirectory = $true
        Description = "Claude Code commands"
    }
    @{
        Source      = "$dotfilesRoot\claude\hooks"
        Target      = "$HOME\.claude\hooks"
        IsDirectory = $true
        Description = "Claude Code hooks"
    }
    @{
        Source      = "$dotfilesRoot\claude\rules"
        Target      = "$HOME\.claude\rules"
        IsDirectory = $true
        Description = "Claude Code path-scoped rules"
    }
    @{
        Source      = "$dotfilesRoot\claude\themes"
        Target      = "$HOME\.claude\themes"
        IsDirectory = $true
        Description = "Claude Code custom themes (catppuccin-frappe)"
    }
    # NOTE: Claude skills are intentionally NOT whole-dir symlinked here.
    # ~\.claude\skills holds plugin-managed junctions; a directory symlink would
    # destroy them. They are linked per-item below (see "Claude skills" loop).

    # --- Codex (global instructions at ~\.codex\AGENTS.md) ---
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.codex\AGENTS.md"
        IsDirectory = $false
        Description = "Codex global instructions (canonical claude\AGENTS.md)"
    }

    # --- opencode (XDG path on Windows: ~\.config\opencode) ---
    @{
        Source      = "$dotfilesRoot\.config\opencode\opencode.jsonc"
        Target      = "$HOME\.config\opencode\opencode.jsonc"
        IsDirectory = $false
        Description = "opencode configuration"
    }
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.config\opencode\AGENTS.md"
        IsDirectory = $false
        Description = "opencode global instructions (canonical claude\AGENTS.md)"
    }
)

# =============================================================================
# Helper Functions
# =============================================================================

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Confirmation {
    param(
        [string]$Message,
        [switch]$DefaultYes
    )

    if ($Force) { return $true }

    $default = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$Message $default"

    if ([string]::IsNullOrEmpty($response)) {
        return $DefaultYes
    }
    return $response -match '^[Yy]'
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    $prefix = switch ($Type) {
        "Info"    { "[*]" }
        "Success" { "[+]" }
        "Warning" { "[!]" }
        "Error"   { "[-]" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )

    # Check if already installed
    $installed = winget list --id $PackageId --exact 2>$null | Select-String $PackageId

    if ($installed) {
        Write-Status "$DisplayName is already installed" -Type Success
        return
    }

    if (-not $Force) {
        if (-not (Request-Confirmation "$DisplayName is not installed. Install it?")) {
            Write-Status "Skipping $DisplayName" -Type Warning
            return
        }
    }

    Write-Status "Installing $DisplayName..." -Type Info

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would run: winget install --id $PackageId" -ForegroundColor DarkGray
        return
    }

    winget install --id $PackageId --accept-package-agreements --accept-source-agreements --silent

    if ($LASTEXITCODE -eq 0) {
        Write-Status "$DisplayName installed successfully" -Type Success
    } else {
        Write-Status "Failed to install $DisplayName" -Type Error
    }
}

function Backup-ExistingConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$Path.backup_$timestamp"

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would backup: $Path -> $backupPath" -ForegroundColor DarkGray
        return
    }

    Move-Item -Path $Path -Destination $backupPath -Force
    Write-Status "Backed up: $Path -> $backupPath" -Type Warning
}

function New-SafeSymlink {
    param(
        [string]$Source,
        [string]$Target,
        [switch]$BackupExisting
    )

    # Check if source exists
    if (-not (Test-Path $Source)) {
        Write-Status "Source does not exist: $Source" -Type Error
        return $false
    }

    # Check if target already exists and is correct symlink
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq "SymbolicLink") {
            $existingTarget = $item.Target
            if ($existingTarget -eq $Source) {
                Write-Status "Symlink already correct: $Target" -Type Success
                return $true
            }
        }

        # Backup or remove existing
        if ($BackupExisting) {
            Backup-ExistingConfig -Path $Target
        } else {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would remove: $Target" -ForegroundColor DarkGray
            } else {
                Remove-Item -Path $Target -Force -Recurse
            }
        }
    }

    # Create parent directory if needed
    $parentDir = Split-Path $Target -Parent
    if (-not (Test-Path $parentDir)) {
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would create directory: $parentDir" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }

    # Create symlink
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create symlink: $Target -> $Source" -ForegroundColor DarkGray
        return $true
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force | Out-Null
        Write-Status "Created: $Target -> $Source" -Type Success
        return $true
    } catch {
        Write-Status "Failed to create symlink: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Install-Kanata {
    # Fetch the latest LLHOOK kanata.exe (the default Windows build — NO Interception
    # driver, so nothing for anti-cheat to flag). NOT the winget 'jtroo.kanata_gui'
    # tray app: we drive start/stop ourselves and a tray wrapper would fight that.
    $dir = Join-Path $env:LOCALAPPDATA 'Programs\kanata'
    $exe = Join-Path $dir 'kanata.exe'
    if (Test-Path $exe) {
        Write-Status "kanata.exe already present: $exe" -Type Success
        return
    }
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would download latest kanata.exe -> $exe" -ForegroundColor DarkGray
        return
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/jtroo/kanata/releases/latest' `
            -Headers @{ 'User-Agent' = 'dotfiles' }
        $asset = $rel.assets | Where-Object { $_.name -eq 'kanata.exe' } | Select-Object -First 1
        if (-not $asset) { throw "No 'kanata.exe' asset in release $($rel.tag_name)" }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe -UseBasicParsing
        Write-Status "Installed kanata $($rel.tag_name) -> $exe" -Type Success
    } catch {
        Write-Status "Failed to install kanata: $($_.Exception.Message)" -Type Error
    }
}

# =============================================================================
# Main Script
# =============================================================================

# Check for admin rights
if (-not (Test-AdminRights)) {
    Write-Status "This script requires Administrator privileges for creating symlinks." -Type Error
    Write-Status "Please run PowerShell as Administrator and try again." -Type Warning
    exit 1
}

# Welcome banner
Write-Host @"

================================================================================
                    Windows Dotfiles Deployment Script
================================================================================

This script will:
  1. Install development tools via winget
  2. Install PowerShell modules
  3. Create symlinks for configuration files
  4. Set up environment variables

Dotfiles location: $dotfilesRoot

"@ -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY RUN MODE - No changes will be made]" -ForegroundColor Yellow
    Write-Host ""
}

if (-not (Request-Confirmation "Do you want to proceed?" -DefaultYes)) {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

# Backup prompt
$doBackup = Request-Confirmation "`nWould you like to backup existing configurations before overwriting?"

# =============================================================================
# Package Installation
# =============================================================================

if (-not $SkipPackages) {
    Write-Host "`n=== Installing Packages ===" -ForegroundColor Magenta

    # --- Install Scoop ---
    Write-Host "`n--- Installing Scoop ---" -ForegroundColor Cyan
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Status "Scoop is already installed" -Type Success
    } else {
        Write-Status "Installing Scoop..." -Type Info
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would install Scoop" -ForegroundColor DarkGray
        } else {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            Write-Status "Scoop installed successfully" -Type Success
        }
    }

    # --- Install Chocolatey ---
    Write-Host "`n--- Installing Chocolatey ---" -ForegroundColor Cyan
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Status "Chocolatey is already installed" -Type Success
    } else {
        Write-Status "Installing Chocolatey..." -Type Info
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would install Chocolatey" -ForegroundColor DarkGray
        } else {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Status "Chocolatey installed successfully" -Type Success
        }
    }

    # --- Install Winget Packages ---
    Write-Host "`n--- Installing Winget Packages ---" -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Status "winget not found. Please install App Installer from Microsoft Store." -Type Error
        exit 1
    }

    foreach ($pkg in $packages) {
        Install-WingetPackage -PackageId $pkg.Id -DisplayName $pkg.Name
    }

    # Install PowerShell modules
    Write-Host "`n--- Installing PowerShell Modules ---" -ForegroundColor Cyan
    foreach ($module in $powershellModules) {
        $installed = Get-Module -ListAvailable -Name $module
        if ($installed) {
            Write-Status "Module already installed: $module" -Type Success
        } else {
            Write-Status "Installing module: $module" -Type Info
            if (-not $DryRun) {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
            } else {
                Write-Host "  [DRY RUN] Would run: Install-Module -Name $module" -ForegroundColor DarkGray
            }
        }
    }

    # Install Catppuccin themes for bat
    Write-Host "`n--- Installing Bat Themes ---" -ForegroundColor Cyan
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        $batConfigDir = (bat --config-dir)
        $batThemesDir = Join-Path $batConfigDir "themes"

        if (-not (Test-Path $batThemesDir)) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would create directory: $batThemesDir" -ForegroundColor DarkGray
            } else {
                New-Item -ItemType Directory -Path $batThemesDir -Force | Out-Null
                Write-Status "Created themes directory: $batThemesDir" -Type Success
            }
        }

        $themes = @("Latte", "Frappe", "Macchiato", "Mocha")
        foreach ($theme in $themes) {
            $themeFile = Join-Path $batThemesDir "Catppuccin $theme.tmTheme"
            $themeUrl = "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20$theme.tmTheme"

            if (Test-Path $themeFile) {
                Write-Status "Catppuccin $theme theme already exists" -Type Success
            } else {
                Write-Status "Downloading Catppuccin $theme theme..." -Type Info
                if ($DryRun) {
                    Write-Host "  [DRY RUN] Would download: $themeUrl" -ForegroundColor DarkGray
                } else {
                    try {
                        Invoke-WebRequest -Uri $themeUrl -OutFile $themeFile -UseBasicParsing
                        Write-Status "Downloaded Catppuccin $theme theme" -Type Success
                    } catch {
                        Write-Status "Failed to download Catppuccin $theme theme: $($_.Exception.Message)" -Type Error
                    }
                }
            }
        }

        Write-Status "Rebuilding bat cache..." -Type Info
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would run: bat cache --build" -ForegroundColor DarkGray
        } else {
            bat cache --build
        }

        Write-Status "Verifying bat themes..." -Type Info
        if (-not $DryRun) {
            $installedThemes = bat --list-themes
            if ($installedThemes -match "Catppuccin") {
                Write-Status "Catppuccin themes installed successfully!" -Type Success
            } else {
                Write-Status "Warning: Catppuccin themes may not be installed correctly" -Type Warning
            }
        }
    } else {
        Write-Status "bat is not installed, skipping theme installation" -Type Warning
    }

    Write-Host "`nInstalling: Kanata (keyboard remapper, LLHOOK)" -ForegroundColor Cyan
    Install-Kanata
}

# =============================================================================
# Symlink Creation
# =============================================================================

if (-not $SkipSymlinks) {
    Write-Host "`n=== Creating Symlinks ===" -ForegroundColor Magenta

    # opencode: remove stale opencode.json so it can't shadow/merge with the tracked .jsonc
    $staleOpencode = "$HOME\.config\opencode\opencode.json"
    if (Test-Path $staleOpencode) {
        if ($DryRun) { Write-Host "  [DRY RUN] Would remove: $staleOpencode" -ForegroundColor DarkGray }
        else { Remove-Item -Path $staleOpencode -Force }
    }

    foreach ($link in $symlinks) {
        Write-Host "`nLinking: $($link.Description)" -ForegroundColor Cyan
        New-SafeSymlink -Source $link.Source -Target $link.Target `
                        -BackupExisting:$doBackup
    }

    # Claude skills: per-item symlinks so we never clobber plugin-managed junctions.
    # Link each repo skill into ~/.claude/skills/<name> ONLY if that name is free.
    Write-Host "`nLinking: Claude Code skills (per-item, preserving plugin junctions)" -ForegroundColor Cyan
    $skillsSrcDir = "$dotfilesRoot\claude\skills"
    $skillsDstDir = "$HOME\.claude\skills"
    if (Test-Path $skillsSrcDir) {
        if (-not (Test-Path $skillsDstDir)) {
            if ($DryRun) { Write-Host "  [DRY RUN] Would create directory: $skillsDstDir" -ForegroundColor DarkGray }
            else { New-Item -ItemType Directory -Path $skillsDstDir -Force | Out-Null }
        }
        foreach ($skill in Get-ChildItem -Path $skillsSrcDir -Directory) {
            $dst = Join-Path $skillsDstDir $skill.Name
            if (Test-Path $dst) {
                Write-Status "Skill '$($skill.Name)' already present (left as-is)" -Type Success
                continue
            }
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would create symlink: $dst -> $($skill.FullName)" -ForegroundColor DarkGray
            } else {
                New-Item -ItemType SymbolicLink -Path $dst -Value $skill.FullName -Force | Out-Null
                Write-Status "Linked skill: $($skill.Name)" -Type Success
            }
        }
    }
}

# =============================================================================
# Environment Variables
# =============================================================================

Write-Host "`n=== Setting Environment Variables ===" -ForegroundColor Magenta

$envVars = @{
    "KOMOREBI_CONFIG_HOME" = "$HOME\.config\komorebi"
    "XDG_CONFIG_HOME"      = "$HOME\.config"
    # Zellij ignores XDG_CONFIG_HOME on Windows; ZELLIJ_CONFIG_DIR gives ~/.config/zellij parity across OSes.
    "ZELLIJ_CONFIG_DIR"    = "$HOME\.config\zellij"
    # Windows-only: Claude Code routes through the local proxy on :8080. The synced
    # ~/.claude/settings.json carries no proxy, so machines without this var (e.g. macOS)
    # talk to the API directly.
    # "ANTHROPIC_BASE_URL"   = "http://localhost:8080"
}

foreach ($var in $envVars.GetEnumerator()) {
    $currentValue = [Environment]::GetEnvironmentVariable($var.Key, "User")
    if ($currentValue -eq $var.Value) {
        Write-Status "$($var.Key) already set correctly" -Type Success
    } else {
        Write-Status "Setting $($var.Key) = $($var.Value)" -Type Info
        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable($var.Key, $var.Value, "User")
        } else {
            Write-Host "  [DRY RUN] Would set environment variable" -ForegroundColor DarkGray
        }
    }
}

# =============================================================================
# Kanata autostart (logon Scheduled Task, un-elevated so Hyper reaches komorebi's AHK)
# =============================================================================

Write-Host "`n=== Registering Kanata logon task ===" -ForegroundColor Magenta

$kanataExe = Join-Path $env:LOCALAPPDATA 'Programs\kanata\kanata.exe'
if (-not (Test-Path $kanataExe)) {
    # Fall back to a scoop/PATH install (scoop shims kanata.exe -> a kanata_windows_*_x64.exe variant).
    $shim = Get-Command kanata -ErrorAction SilentlyContinue
    if ($shim) { $kanataExe = $shim.Source }
}
$kanataCfg = Join-Path $HOME '.config\kanata\kanata.win.kbd'
if ($DryRun) {
    Write-Host "  [DRY RUN] Would register logon task 'Kanata' -> $kanataExe --cfg $kanataCfg" -ForegroundColor DarkGray
} elseif (-not (Test-Path $kanataExe)) {
    Write-Status "kanata.exe not found ($kanataExe) — run without -SkipPackages first" -Type Warning
} else {
    # Hidden launch: pwsh starts kanata with a hidden window so no console lingers.
    $cmd = "Start-Process '$kanataExe' -ArgumentList '--cfg','$kanataCfg' -WindowStyle Hidden"
    $action    = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$cmd`""
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'Kanata' -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Status "Registered logon task 'Kanata' (disable if you log in on the Voyager)" -Type Success
}

# --- Hyper-key enabler: neutralize Windows' reserved Ctrl+Shift+Alt+Win (Office/Copilot) shortcut ---
# Without this, tapping the Hyper key alone pops the Office/Copilot UI. Per-user + reversible.
# Undo: Remove-Item 'HKCU:\Software\Classes\ms-officeapp' -Recurse -Force
$officeKey = 'HKCU:\Software\Classes\ms-officeapp\Shell\Open\Command'
$officeVal = (Get-ItemProperty -Path $officeKey -ErrorAction SilentlyContinue).'(default)'
if ($officeVal -eq 'rundll32') {
    Write-Status "Hyper-key Office/Copilot shortcut already neutralized" -Type Success
} else {
    Write-Status "Neutralizing Ctrl+Shift+Alt+Win Office/Copilot shortcut (Hyper-key enabler)" -Type Info
    if (-not $DryRun) {
        New-Item -Path $officeKey -Value 'rundll32' -Force | Out-Null
    } else {
        Write-Host "  [DRY RUN] Would set $officeKey (default) = rundll32" -ForegroundColor DarkGray
    }
}

# --- Claude toast click → focus the waiting WezTerm pane ---
# Registers the claude-wez:// URL protocol so a toast body-click runs claude-notify.ps1
# in -Activate mode (drops a one-shot focus marker the WezTerm poller consumes). Per-user,
# reversible. Undo: Remove-Item 'HKCU:\Software\Classes\claude-wez' -Recurse -Force
$wezCmdKey   = 'HKCU:\Software\Classes\claude-wez\shell\open\command'
$launcherVbs = "$HOME\.claude\hooks\bin\claude-wez-launch.vbs"
# Route the click through the windowless VBS launcher: wscript has no console, so no
# Windows-Terminal flash (the spike proved pwsh-direct flashes). The VBS runs
# claude-notify.ps1 -Activate hidden and resolves pwsh from PATH at click time.
# wscript.exe is always present on Windows.
$wezCmdWant  = "wscript.exe `"$launcherVbs`" `"%1`""
$wezCmdHave  = (Get-ItemProperty -Path $wezCmdKey -ErrorAction SilentlyContinue).'(default)'
if ($wezCmdHave -eq $wezCmdWant) {
    Write-Status "claude-wez toast-click handler already registered" -Type Success
} else {
    Write-Status "Registering claude-wez:// toast-click handler (focus the waiting pane)" -Type Info
    if (-not $DryRun) {
        New-Item -Path 'HKCU:\Software\Classes\claude-wez\shell\open\command' -Force | Out-Null
        Set-ItemProperty 'HKCU:\Software\Classes\claude-wez' '(default)'   'URL:Claude WezTerm Focus'
        Set-ItemProperty 'HKCU:\Software\Classes\claude-wez' 'URL Protocol' ''
        Set-ItemProperty $wezCmdKey '(default)' $wezCmdWant
    } else {
        Write-Host "  [DRY RUN] Would set $wezCmdKey (default) = $wezCmdWant" -ForegroundColor DarkGray
    }
}

# --- AI tool secrets + context7 MCP registration ---
$secretsFile = "$HOME\.config\dotfiles\secrets.env"
if (Test-Path $secretsFile) {
    # Parse `export KEY="value"` lines and set them as user env vars
    Get-Content $secretsFile | ForEach-Object {
        if ($_ -match '^\s*export\s+([A-Z_][A-Z0-9_]*)\s*=\s*"?([^"]*)"?\s*$') {
            $name = $Matches[1]; $value = $Matches[2]
            if ($DryRun) { Write-Host "  [DRY RUN] Would set env $name" -ForegroundColor DarkGray }
            else { [Environment]::SetEnvironmentVariable($name, $value, "User"); Set-Item "env:$name" $value }
        }
    }
} else {
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create $secretsFile from secrets.env.example" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Path "$HOME\.config\dotfiles" -Force | Out-Null
        Copy-Item "$dotfilesRoot\secrets.env.example" $secretsFile
        Write-Status "Created $secretsFile - fill in CONTEXT7_API_KEY." -Type Warning
    }
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would (re)register context7 MCP server" -ForegroundColor DarkGray
    } else {
        claude mcp remove context7 --scope user 2>$null
        claude mcp add --scope user --transport http context7 `
            https://mcp.context7.com/mcp `
            --header 'CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}'
    }
}

# =============================================================================
# Powerline Fonts
# =============================================================================

if (-not $SkipFonts) {
    Write-Host "`n=== Installing Powerline Fonts ===" -ForegroundColor Magenta
    $powerlinePath = "$env:TEMP\powerline-fonts"

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would clone and install Powerline fonts" -ForegroundColor DarkGray
    } else {
        if (Test-Path $powerlinePath) {
            Remove-Item -Recurse -Force $powerlinePath
        }
        Write-Status "Cloning powerline/fonts repository..." -Type Info
        git clone https://github.com/powerline/fonts.git $powerlinePath --depth=1 --quiet
        Push-Location $powerlinePath
        Write-Status "Installing Powerline fonts..." -Type Info
        & .\install.ps1
        Pop-Location
        Remove-Item -Recurse -Force $powerlinePath
        Write-Status "Powerline fonts installed and temp files cleaned up" -Type Success
    }
} else {
    Write-Status "Skipping Powerline fonts installation" -Type Warning
}

# =============================================================================
# Post-Install
# =============================================================================

Write-Host @"

================================================================================
                           Setup Complete!
================================================================================

Next steps:

  1. Restart PowerShell to load new profile

  2. Open Neovim and run :Lazy sync to install plugins
     > nvim

  3. Start Komorebi tiling window manager
     > komorebic start

  4. (Optional) Run the AutoHotkey script for keybindings
     > $HOME\.config\komorebi\komorebi.ahk

  5. Wezterm should automatically pick up config from
     $HOME\.config\wezterm

  6. Start the YASB status bar (replaces komorebi-bar)
     > yasb
     Enable launch-at-login (one-time): > yasbc enable-autostart

================================================================================
"@ -ForegroundColor Green
