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
.PARAMETER Manifests
    Which winget manifests to import (core, dev, gamedev, comfort, optional).
    Default: core, dev, gamedev, comfort.
.PARAMETER IncludeOptional
    Also import the optional manifest (game launchers, chat/media) and install
    the scoop opt-in packages (psmux, zellij, opencode) + kanata.
.NOTES
    Requires Administrator privileges for creating symbolic links
#>

param(
    [switch]$SkipPackages,
    [switch]$SkipSymlinks,
    [switch]$SkipFonts,
    [switch]$Force,
    [switch]$DryRun,
    [ValidateSet('core', 'dev', 'gamedev', 'comfort', 'optional')]
    [string[]]$Manifests = @('core', 'dev', 'gamedev', 'comfort'),
    [switch]$IncludeOptional
)

# =============================================================================
# Configuration
# =============================================================================

$dotfilesRoot = $PSScriptRoot

$powershellModules = @(
    "PSReadLine"
    "BurntToast"   # clickable Claude toasts (claude-notify.ps1 emit mode)
    # posh-git + Terminal-Icons removed 2026-07-04 — redundant with Starship + eza --icons (see profile).
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
        Source      = "$dotfilesRoot\.config\profile"
        Target      = "$HOME\.config\profile"
        IsDirectory = $true
        Description = "Gaming/work profile toggle"
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
        Source      = "$dotfilesRoot\.config\wsl\wslconfig"
        Target      = "$HOME\.wslconfig"
        IsDirectory = $false
        Description = "WSL2 utility-VM resource limits"
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
        Source      = "$dotfilesRoot\.config\windows-terminal\settings.json"
        Target      = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        IsDirectory = $false
        Description = "Windows Terminal (stable) settings"
    }
    @{
        Source      = "$dotfilesRoot\.config\windows-terminal\settings.json"
        Target      = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        IsDirectory = $false
        Description = "Windows Terminal (Preview) settings"
    }

    # --- Global agent instructions: one canonical file (claude\AGENTS.md) ---
    # Single source of truth shared by Claude Code, Codex, opencode, pi, and Copilot.
    # Claude Code reads it under the CLAUDE.md name; Codex/opencode/pi read it as
    # AGENTS.md; Copilot reads it as copilot-instructions.md (see below).
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
    # NOTE: Claude agents, commands, hooks, rules, themes, and skills are intentionally
    # NOT whole-dir symlinked. Each of these ~\.claude\<dir> folders must stay a REAL
    # directory so plugins/tools (e.g. oh-my-claudecode) can drop their own files
    # alongside ours — a directory symlink would either clobber that content or route
    # their writes into this repo (the failure that once emptied claude\agents). They
    # are linked per-item below (see the New-PerItemLinks calls and "Claude skills" loop).

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

    # --- pi (global instructions at ~\.pi\agent\AGENTS.md) ---
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.pi\agent\AGENTS.md"
        IsDirectory = $false
        Description = "pi global instructions (canonical claude\AGENTS.md)"
    }

    # --- GitHub Copilot CLI (native personal-instructions file; NOT named AGENTS.md) ---
    @{
        Source      = "$dotfilesRoot\claude\AGENTS.md"
        Target      = "$HOME\.copilot\copilot-instructions.md"
        IsDirectory = $false
        Description = "Copilot CLI global instructions (canonical claude\AGENTS.md)"
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

function Import-WingetManifest {
    param([string]$Name)

    $file = Join-Path $dotfilesRoot "packages\winget-$Name.json"
    if (-not (Test-Path $file)) {
        Write-Status "Manifest not found: $file" -Type Error
        return
    }

    if ($DryRun) {
        $ids = (Get-Content $file -Raw | ConvertFrom-Json).Sources[0].Packages.PackageIdentifier
        Write-Host "  [DRY RUN] Would import '$Name' ($($ids.Count) packages):" -ForegroundColor DarkGray
        $ids | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        return
    }

    Write-Status "Importing manifest: $Name" -Type Info
    winget import -i $file --accept-package-agreements --accept-source-agreements --ignore-unavailable
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Manifest '$Name' imported" -Type Success
    } else {
        # winget import exits nonzero when any entry fails OR is already installed;
        # report and continue - never abort the deploy over one manifest.
        Write-Status "Manifest '$Name' finished with exit code $LASTEXITCODE (failed or already-installed entries; see output above)" -Type Warning
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

    # --- Import Winget Manifests ---
    Write-Host "`n--- Importing Winget Manifests ---" -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Status "winget not found. Please install App Installer from Microsoft Store." -Type Error
        exit 1
    }

    $selectedManifests = $Manifests
    if ($IncludeOptional -and $selectedManifests -notcontains 'optional') {
        $selectedManifests += 'optional'
    }
    foreach ($name in $selectedManifests) {
        Import-WingetManifest -Name $name
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

    # --- Scoop opt-in packages (all in the 'main' bucket) ---
    if ($IncludeOptional) {
        Write-Host "`n--- Installing Scoop Opt-in Packages ---" -ForegroundColor Cyan
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            foreach ($pkg in @('psmux', 'zellij', 'opencode')) {
                if (Get-Command $pkg -ErrorAction SilentlyContinue) {
                    Write-Status "$pkg already installed" -Type Success
                } elseif ($DryRun) {
                    Write-Host "  [DRY RUN] Would run: scoop install $pkg" -ForegroundColor DarkGray
                } else {
                    scoop install $pkg
                }
            }
        } else {
            Write-Status "scoop not available; skipping scoop opt-in packages" -Type Error
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

    if ($IncludeOptional) {
        Write-Host "`nInstalling: Kanata (keyboard remapper, LLHOOK)" -ForegroundColor Cyan
        Install-Kanata
    } else {
        Write-Status "Kanata skipped (opt-in; re-run with -IncludeOptional)" -Type Info
    }
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

    # Windows Terminal: remove retired theme fragment — scheme now lives in the
    # shared settings.json; leaving it would define "Catppuccin Frappe" twice.
    $staleWtFragment = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles"
    if (Test-Path $staleWtFragment) {
        if ($DryRun) { Write-Host "  [DRY RUN] Would remove: $staleWtFragment" -ForegroundColor DarkGray }
        else { Remove-Item -Path $staleWtFragment -Recurse -Force }
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

    # Claude agents/commands/hooks/rules/themes: per-item symlinks so plugins/tools can
    # coexist in these ~/.claude dirs. Link each top-level child (file OR subdir) into
    # ~/.claude/<dir>/<name> ONLY if that name is free, mirroring the skills strategy.
    # Self-heals a legacy whole-dir symlink by removing the reparse point first (this
    # never touches the target contents in the repo — see the agents-data-loss note).
    function New-PerItemLinks($srcDir, $dstDir, $label) {
        Write-Host "`nLinking: $label (per-item, preserving plugin/tool files)" -ForegroundColor Cyan
        if (-not (Test-Path $srcDir)) { Write-Status "Source missing, skipped: $srcDir" -Type Info; return }
        $dstItem = Get-Item $dstDir -Force -ErrorAction SilentlyContinue
        if ($dstItem -and $dstItem.LinkType) {
            if ($DryRun) { Write-Host "  [DRY RUN] Would remove legacy whole-dir symlink: $dstDir" -ForegroundColor DarkGray }
            else { $dstItem.Delete(); Write-Status "Removed legacy whole-dir symlink: $dstDir" -Type Info }
        }
        if (-not (Test-Path $dstDir)) {
            if ($DryRun) { Write-Host "  [DRY RUN] Would create directory: $dstDir" -ForegroundColor DarkGray }
            else { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        }
        foreach ($child in Get-ChildItem -Path $srcDir -Force) {
            $dst = Join-Path $dstDir $child.Name
            if (Test-Path $dst) {
                Write-Status "'$($child.Name)' already present (left as-is)" -Type Success
                continue
            }
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would create symlink: $dst -> $($child.FullName)" -ForegroundColor DarkGray
            } else {
                New-Item -ItemType SymbolicLink -Path $dst -Value $child.FullName -Force | Out-Null
                Write-Status "Linked: $($child.Name)" -Type Success
            }
        }
    }

    New-PerItemLinks "$dotfilesRoot\claude\agents"   "$HOME\.claude\agents"   "Claude Code agents"
    New-PerItemLinks "$dotfilesRoot\claude\commands" "$HOME\.claude\commands" "Claude Code commands"
    New-PerItemLinks "$dotfilesRoot\claude\hooks"    "$HOME\.claude\hooks"    "Claude Code hooks"
    New-PerItemLinks "$dotfilesRoot\claude\rules"    "$HOME\.claude\rules"    "Claude Code path-scoped rules"
    New-PerItemLinks "$dotfilesRoot\claude\themes"   "$HOME\.claude\themes"   "Claude Code custom themes (catppuccin-frappe)"
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
    # zoxide's DB is relocated here by the pwsh profile ($env:_ZO_DATA_DIR, profile:22), but that is
    # session-only: taskbar/Start-launched GUIs never run the profile, so WezTerm's workspace switcher
    # (Ctrl+Space f -> cmd /c zoxide query -l) read an empty default DB and showed no zoxide dirs.
    # Persisting it at User scope points every launch path at the same DB.
    "_ZO_DATA_DIR"         = "$HOME\ZoxideData"
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
# Kanata autostart — ownership moved to dotfiles-profile-boot (2026-07-13)
# =============================================================================
# The standalone 'Kanata' AtLogOn task used to start kanata unconditionally. That
# now races the profile-boot task, which owns kanata startup via the $Apps table
# (starts it on work boots, kills it on gaming boots): gaming boots would see
# this task restart kanata right after the profile kill, and work boots could
# double-start it (two LLHOOK instances). Remove the standalone task; the config
# symlink and kanata itself are untouched.

Write-Host "`n=== Removing standalone Kanata logon task (superseded by dotfiles-profile-boot) ===" -ForegroundColor Magenta

$existingKanataTask = Get-ScheduledTask -TaskName 'Kanata' -ErrorAction SilentlyContinue
if ($DryRun) {
    if ($existingKanataTask) {
        Write-Host "  [DRY RUN] Would remove logon task 'Kanata' (schtasks /delete /tn Kanata /f)" -ForegroundColor DarkGray
    } else {
        Write-Host "  [DRY RUN] 'Kanata' logon task not present; nothing to remove" -ForegroundColor DarkGray
    }
} elseif ($existingKanataTask) {
    schtasks /delete /tn 'Kanata' /f | Out-Null
    Write-Status "Removed logon task 'Kanata' (startup now owned by dotfiles-profile-boot)" -Type Success
} else {
    Write-Status "'Kanata' logon task not present (already removed)" -Type Success
}

# =============================================================================
# Gaming/work profile tasks (design: docs/specs/2026-07-13-gaming-profile-design.md)
#   dotfiles-profile-elevated : on-demand, RunLevel Highest — OpenVPN services + bcdedit.
#                               Triggered by schtasks /run from profile-toggle.ps1 (no UAC).
#   dotfiles-profile-boot     : at logon — replays the marker profile (staggered starts).
# =============================================================================

Write-Host "`n=== Registering profile toggle tasks ===" -ForegroundColor Magenta

$profileScript  = Join-Path $HOME '.config\profile\profile-toggle.ps1'
$elevatedScript = Join-Path $HOME '.config\profile\profile-elevated.ps1'
if ($DryRun) {
    Write-Host "  [DRY RUN] Would register 'dotfiles-profile-elevated' + 'dotfiles-profile-boot'" -ForegroundColor DarkGray
} else {
    # Elevated on-demand task: no trigger — fired via `schtasks /run`.
    $eAction    = New-ScheduledTaskAction -Execute 'pwsh.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -File `"$elevatedScript`""
    $ePrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive -RunLevel Highest
    $eSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'dotfiles-profile-elevated' -Action $eAction `
        -Principal $ePrincipal -Settings $eSettings -Force | Out-Null
    Write-Status "Registered 'dotfiles-profile-elevated' (on-demand, elevated)" -Type Success

    # Boot task: logon trigger, un-elevated (starts tray apps in the user session).
    $bAction    = New-ScheduledTaskAction -Execute 'pwsh.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -File `"$profileScript`" -Boot"
    $bTrigger   = New-ScheduledTaskTrigger -AtLogOn
    $bPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive -RunLevel Limited
    $bSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'dotfiles-profile-boot' -Action $bAction -Trigger $bTrigger `
        -Principal $bPrincipal -Settings $bSettings -Force | Out-Null
    Write-Status "Registered 'dotfiles-profile-boot' (logon, replays marker profile)" -Type Success
}

# =============================================================================
# One-time gaming + dev optimizations
# (research + rationale: docs/specs/2026-07-13-gaming-profile-design.md)
# =============================================================================

Write-Host "`n=== One-time gaming/dev optimizations ===" -ForegroundColor Magenta

function Set-RegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if ($DryRun) { Write-Host "  [DRY RUN] $Path\$Name = $Value" -ForegroundColor DarkGray; return }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

# Game DVR / background recording off (input overhead + disk churn)
Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
# Game Mode on (+2.7-3.3% avg fps, best on 1% lows; defers update installs mid-game)
Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
# HAGS on (frame-time benefit; required for DLSS Frame Gen). Reboot-bound.
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
# Raw mouse input (competitive aim): pointer acceleration off
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
# Long paths for dev tooling (Unity ignores it - keep project roots short anyway)
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
if (-not $DryRun) { git config --global core.longpaths true }
# Storage Sense auto-clean off - its "temporary files" pass deletes DirectX shader caches
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0
if ($DryRun) {
    Write-Host "  [DRY RUN] Would apply registry optimizations (HAGS needs a reboot)" -ForegroundColor DarkGray
} else {
    Write-Status "Registry optimizations applied (HAGS needs a reboot)" -Type Success
}

# Power plan: ensure a high-performance scheme is active (work needs compile perf too).
# This box already runs 'Ultimate Performance'; only intervene if we're on Balanced/saver.
$activePlan = (powercfg /getactivescheme)
if ($activePlan -match '(Balanced|Power saver)') {
    $ultimate = (powercfg /list | Select-String 'Ultimate Performance' | Select-Object -First 1)
    if ($ultimate -and $ultimate.ToString() -match '([0-9a-f-]{36})') {
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would switch power plan to Ultimate Performance" -ForegroundColor DarkGray
        } else {
            powercfg /setactive $Matches[1]
            Write-Status "Switched power plan to Ultimate Performance" -Type Success
        }
    } else {
        Write-Status "No Ultimate Performance plan found - create one: powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61" -Type Warning
    }
} else {
    Write-Status "High-performance power plan already active" -Type Success
}

# Defender exclusions - NARROW scope: regenerable engine caches only (spec has the tradeoff).
# Unity project Library/Temp dirs are discovered per-project (dirs with a ProjectSettings sibling).
$defenderPaths = @(
    (Join-Path $env:ProgramData 'Epic\Zen\Data')     # Unreal 5.4+ local DDC
    (Join-Path $env:APPDATA 'Godot')                  # Godot editor + shader cache
)
foreach ($root in @('D:\Projects', (Join-Path $HOME 'Projects'))) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'ProjectSettings' } |
        ForEach-Object {
            $defenderPaths += (Join-Path $_.Parent.FullName 'Library')
            $defenderPaths += (Join-Path $_.Parent.FullName 'Temp')
        }
}
foreach ($p in $defenderPaths) {
    if ($DryRun) { Write-Host "  [DRY RUN] Defender exclusion: $p" -ForegroundColor DarkGray }
    else { Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue }
}
Write-Status "Defender exclusions: $($defenderPaths.Count) paths (re-run deploy after new Unity projects; tune with Get-MpPerformanceReport -TopScans 20)" -Type Success

# Native autostarts -> removed; the dotfiles-profile-boot task owns startup now.
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$ownedAutostarts = @('Docker Desktop', 'com.squirrel.slack.slack', 'Steam', 'GoogleDriveFS', 'org.openvpn.client')
foreach ($name in $ownedAutostarts) {
    if ($DryRun) { Write-Host "  [DRY RUN] Remove Run entry: $name" -ForegroundColor DarkGray }
    else { Remove-ItemProperty -Path $runKey -Name $name -ErrorAction SilentlyContinue }
}
# jusched (Java updater) - junk, gone for good (lives in HKLM on 64-bit Java installs)
foreach ($jk in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    if (-not $DryRun) { Remove-ItemProperty -Path $jk -Name 'SunJavaUpdateSched' -ErrorAction SilentlyContinue }
}
Write-Status "Native autostarts removed for profile-managed apps" -Type Success

# Things Windows/apps won't let us script - print the manual checklist once.
Write-Host @"

  MANUAL follow-ups (one-time, can't be scripted sanely):
   - Docker Desktop > Settings > General: UNTICK 'Start Docker Desktop when you sign in'
     (it re-adds its Run key on update if left on; same for Slack > Preferences,
      Steam > Settings > Interface, Discord > Settings > Windows Settings)
   - PowerToys Settings > General: 'Run at startup' OFF
   - Settings > System > Notifications > Do not disturb: turn ON 'When playing a game'
     (stored in CloudStore binary blobs - not scriptable)
   - Settings > Privacy & security > Searching Windows: exclude D:\Projects and ~\Projects
   - NVIDIA App/Control Panel: in-game Reflex ON where offered; driver Low Latency = Ultra
     only for non-Reflex DX9-11 titles (does nothing in DX12/Vulkan)
   - Raycast > Settings > Extensions > Script Commands: add directory
     $dotfilesRoot\raycast\scripts
   - Raycast for Windows: no winget package - download installer from https://raycast.com
   - Keep the GPU driver current (Oct 2025 KB5066835 regression was fixed in 581.94)
"@ -ForegroundColor Yellow

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
