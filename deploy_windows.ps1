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
.NOTES
    Requires Administrator privileges for creating symbolic links
#>

param(
    [switch]$SkipPackages,
    [switch]$SkipSymlinks,
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

    # Fonts
    @{ Id = "DEVCOM.JetBrainsMonoNerdFont"; Name = "JetBrainsMono Nerd Font" }
)

$powershellModules = @(
    "posh-git"
    "Terminal-Icons"
    "PSReadLine"
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
        Source      = "$dotfilesRoot\.config\nvim"
        Target      = "$env:LOCALAPPDATA\nvim"
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

    # File symlinks
    @{
        Source      = "$dotfilesRoot\.config\starship.toml"
        Target      = "$HOME\.config\starship.toml"
        IsDirectory = $false
        Description = "Starship prompt"
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
}

# =============================================================================
# Symlink Creation
# =============================================================================

if (-not $SkipSymlinks) {
    Write-Host "`n=== Creating Symlinks ===" -ForegroundColor Magenta

    foreach ($link in $symlinks) {
        Write-Host "`nLinking: $($link.Description)" -ForegroundColor Cyan
        New-SafeSymlink -Source $link.Source -Target $link.Target `
                        -BackupExisting:$doBackup
    }
}

# =============================================================================
# Environment Variables
# =============================================================================

Write-Host "`n=== Setting Environment Variables ===" -ForegroundColor Magenta

$envVars = @{
    "KOMOREBI_CONFIG_HOME" = "$HOME\.config\komorebi"
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
# Powerline Fonts
# =============================================================================

if (-not $SkipPackages) {
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

================================================================================
"@ -ForegroundColor Green
