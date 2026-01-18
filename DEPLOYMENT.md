# Deployment Guide

This repository provides three deployment scripts optimized for different platforms and use cases. Choose the appropriate script based on your operating system and requirements.

## Script Comparison

| Script | Platform | Prerequisites | Purpose | Package Manager |
|--------|----------|---------------|---------|-----------------|
| `deploy_windows.ps1` | Windows 10/11 | PowerShell 7+, Admin | Full Windows setup | winget |
| `setup_mac.sh` | macOS | Xcode CLI Tools | macOS-specific tools | Homebrew |
| `deploy.sh` | Linux/macOS | curl, zsh | Universal setup | auto-detect |

## deploy_windows.ps1

**Platform**: Windows 10/11
**Requirements**: PowerShell 7+, Administrator privileges
**Execution Policy**: May require `Set-ExecutionPolicy RemoteSigned`

### Features

- Installs packages via winget (PowerShell 7, Git, JetBrains Mono Nerd Font, etc.)
- Creates symbolic links for all config directories
- Sets environment variables (`XDG_CONFIG_HOME`, `KOMOREBI_CONFIG_HOME`)
- Supports dry-run mode for previewing changes

### Usage

```powershell
# Full setup (recommended for first-time setup)
.\deploy_windows.ps1

# Skip package installation (useful for config updates only)
.\deploy_windows.ps1 -SkipPackages

# Preview changes without executing
.\deploy_windows.ps1 -DryRun
```

### What Gets Installed

**Packages** (via winget):
- PowerShell (Microsoft.PowerShell)
- Git (Git.Git)
- JetBrains Mono Nerd Font (JetBrains.JetBrainsMono.NerdFont)

**Symlinks Created**:
- `.config/nvim` → `$HOME\.config\nvim`
- `.config/wezterm` → `$HOME\.config\wezterm`
- `.config/komorebi` → `$HOME\.config\komorebi`
- `.config/yazi` → `$env:APPDATA\yazi\config`
- `.config/lazygit` → `$env:APPDATA\lazygit`
- `.config/starship.toml` → `$HOME\.config\starship.toml`
- `.config/powershell/Microsoft.PowerShell_profile.ps1` → `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `.ideavimrc` → `$HOME\.ideavimrc`

**Environment Variables**:
- `XDG_CONFIG_HOME` = `$HOME\.config`
- `KOMOREBI_CONFIG_HOME` = `$HOME\.config\komorebi`

### Post-Installation

1. Restart PowerShell to load new profile
2. Install additional tools: `winget install Neovim.Neovim wez.wezterm`
3. Start Komorebi: `komorebic start`

---

## setup_mac.sh

**Platform**: macOS (tested on Monterey+)
**Requirements**: Xcode Command Line Tools (`xcode-select --install`)

### Features

- Installs Homebrew if not present
- Installs formulae (CLI tools) and casks (GUI apps)
- Creates symlinks for configs
- Starts services (yabai, skhd)

### Usage

```bash
chmod +x setup_mac.sh
./setup_mac.sh
```

### What Gets Installed

**Homebrew Formulae** (partial list):
- neovim, tmux, zsh, starship
- yazi, lazygit, ripgrep, fd, eza, bat
- node, python, go

**Homebrew Casks**:
- font-jetbrains-mono-nerd-font
- wezterm

**Services Started**:
- yabai (tiling window manager)
- skhd (hotkey daemon)

**Symlinks Created**:
- All `.config/*` directories to `~/.config/`
- `tmux/tmux.conf` → `~/.tmux.conf`
- `zsh/zshrc_manager.sh` → `~/.zshrc`
- `.ideavimrc` → `~/.ideavimrc`

### Post-Installation

1. Restart terminal or `source ~/.zshrc`
2. Launch Neovim and run `:Lazy sync`
3. Configure Yabai permissions in System Settings if needed

---

## deploy.sh

**Platform**: Linux (Debian/Ubuntu, Arch, Fedora) and macOS
**Requirements**: curl, zsh

### Features

- Auto-detects package manager (apt, pacman, yum, dnf, brew)
- Installs oh-my-zsh with plugins
- Creates symlinks for configs
- Platform-agnostic (works on any Unix-like system)

### Usage

```bash
chmod +x deploy.sh
./deploy.sh
```

### What Gets Installed

**Package Manager Detection** (auto-selected):
- Debian/Ubuntu: `apt`
- Arch Linux: `pacman`
- Fedora/RHEL: `dnf` or `yum`
- macOS: `brew`

**Oh-My-Zsh**:
- Framework installed to `~/.oh-my-zsh`
- Plugins: zsh-autosuggestions, zsh-syntax-highlighting

**Symlinks Created**:
- All `.config/*` directories to `~/.config/`
- `tmux/tmux.conf` → `~/.tmux.conf`
- `zsh/zshrc_manager.sh` → `~/.zshrc`
- `.ideavimrc` → `~/.ideavimrc`

### Post-Installation

1. Change default shell: `chsh -s $(which zsh)`
2. Restart terminal
3. Install Tmux Plugin Manager: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
4. Press `Ctrl+Space I` in tmux to install plugins

---

## Choosing the Right Script

### Use `deploy_windows.ps1` if:
- You're on Windows 10/11
- You want automated package installation via winget
- You need Komorebi window manager setup
- You want environment variables configured automatically

### Use `setup_mac.sh` if:
- You're on macOS
- You want Homebrew package management
- You need Yabai/SKHD window manager setup
- You want services started automatically

### Use `deploy.sh` if:
- You're on Linux or prefer a universal approach
- You want oh-my-zsh installed
- You're setting up on a server or minimal system
- You prefer manual package installation
- The macOS script doesn't work for your setup

---

## Troubleshooting

### Windows Symlink Errors
**Issue**: "Access denied" when creating symlinks
**Solution**: Run PowerShell as Administrator

### macOS Permission Denied
**Issue**: Cannot execute script
**Solution**: Run `chmod +x setup_mac.sh` before executing

### Homebrew Not Found (macOS)
**Issue**: Script can't find `brew` command
**Solution**: Install manually: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Tmux Plugins Not Loading
**Issue**: Tmux appears unstyled
**Solution**: Install TPM and run `Prefix + I` to install plugins

### Zsh Not Default Shell
**Issue**: Still using bash after installation
**Solution**: Run `chsh -s $(which zsh)` and restart terminal

---

## Re-running Scripts

All scripts are idempotent and safe to re-run:
- Existing symlinks will be skipped or updated
- Packages already installed will be skipped
- No data loss from re-running

**Use cases for re-running**:
- After pulling new config changes from git
- After adding new dotfiles to the repository
- To repair broken symlinks
- To update packages (on Windows/macOS scripts)

---

## Manual Installation Alternative

If deployment scripts don't work for your system, manually symlink configs:

```bash
# Create config directory
mkdir -p ~/.config

# Symlink individual configs
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
ln -sf ~/dotfiles/.config/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles/zsh/zshrc_manager.sh ~/.zshrc
ln -sf ~/dotfiles/.ideavimrc ~/.ideavimrc

# ... repeat for other configs
```
