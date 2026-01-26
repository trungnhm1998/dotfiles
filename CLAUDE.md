@AGENTS.md
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managing configurations for a complete development environment across macOS, Linux, and Windows. The setup emphasizes terminal-based tools, modal (vim) editing, and tiling window managers.

## Setup Commands

**Windows (run as Administrator in PowerShell 7+):**
```powershell
.\deploy_windows.ps1              # Full setup: packages, symlinks, env vars
.\deploy_windows.ps1 -SkipPackages  # Symlinks only
.\deploy_windows.ps1 -DryRun        # Preview changes without executing
```

**macOS:**
```bash
./setup_mac.sh  # Installs Homebrew packages, creates symlinks, starts services
```

**Linux/Mac (universal):**
```bash
./deploy.sh  # Installs dependencies, oh-my-zsh, creates symlinks
```

## Validation Commands

```bash
# Shell scripts - syntax check
bash -n deploy.sh
shellcheck script.sh

# Neovim - verify plugins and health
nvim -c ':Lazy sync' -c ':checkhealth'

# PowerShell - syntax check
powershell -Command "Get-Command -Syntax .\deploy_windows.ps1"
```

## Architecture

### Windows Symlink Mappings

| Source | Target |
|--------|--------|
| `.config/nvim` | `$HOME\.config\nvim` |
| `.config/wezterm` | `$HOME\.config\wezterm` |
| `.config/komorebi` | `$HOME\.config\komorebi` |
| `.config/yazi` | `$env:APPDATA\yazi\config` (note: different from XDG) |
| `.config/lazygit` | `$env:APPDATA\lazygit` |
| `.config/starship.toml` | `$HOME\.config\starship.toml` |
| `.config/powershell/Microsoft.PowerShell_profile.ps1` | `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `.ideavimrc` | `$HOME\.ideavimrc` |
| `zed/settings.json` | `$env:APPDATA\Zed\settings.json` |
| `zed/keymap.json` | `$env:APPDATA\Zed\keymap.json` |

**Environment Variables (set by deploy script):**
| Variable | Value |
|----------|-------|
| `XDG_CONFIG_HOME` | `$HOME\.config` |
| `KOMOREBI_CONFIG_HOME` | `$HOME\.config\komorebi` |

### Platform-Specific Workflows

**macOS/Linux:** Tmux-centric workflow
- Tmux for terminal multiplexing with TPM plugin manager
- vim-tmux-navigator for Ctrl+hjkl navigation across tmux panes and vim splits
- Zsh auto-attaches to tmux session (skipped in IDE terminals)

**Windows:** Wezterm-centric workflow (no tmux)
- Wezterm workspaces replace tmux sessions
- Leader key: `Ctrl+Space` (1 second timeout)
- vim-smart-splits plugin enables Ctrl+hjkl navigation between Wezterm panes and Neovim splits
- Key bindings: `Leader+v` (hsplit), `Leader+s` (vsplit), `Leader+x` (close pane), `Leader+t` (new tab), `Leader+1-9` (switch tabs)

### Window Management

- **macOS:** Yabai (tiling) + SKHD (hotkeys) + SketchyBar (status bar)
- **Windows:** Komorebi (tiling) + per-monitor status bars. Start with `komorebic start`. Config requires `KOMOREBI_CONFIG_HOME` env var pointing to `$HOME\.config\komorebi`

### Editor Stack

- **Neovim:** LazyVim framework with Lazy.nvim plugin manager
  - Config: `.config/nvim/init.lua` bootstraps LazyVim
  - Plugins defined in `.config/nvim/lua/plugins/`
  - After install, run `:Lazy sync` to install plugins
- **Wezterm:** Primary terminal with Lua config at `.config/wezterm/wezterm.lua`

### Shell Configuration

Zsh loads via `zshrc_manager.sh` which:
1. Detects IDE terminals (IntelliJ, VSCode, Cursor) and skips tmux attachment
2. Sources `zshrc.sh` for aliases, plugins, and environment setup
3. Auto-attaches to tmux session outside IDEs (macOS/Linux only)

Key aliases: `y` (yazi with cd-on-exit), `cd` (aliased to zoxide `z`), `ls/ll/la/lt` (eza variants)

### Cross-Tool Integration

- **Navigation:** Ctrl+hjkl works across tmux/wezterm panes and vim splits
- **Theme:** Catppuccin Frappe used consistently (wezterm, tmux, yazi, komorebi)
- **Font:** JetBrains Mono Nerd Font

## Key Configuration Files

| Tool | Config Location |
|------|-----------------|
| Neovim | `.config/nvim/` |
| Wezterm | `.config/wezterm/wezterm.lua` |
| Komorebi | `.config/komorebi/komorebi.json` |
| Yabai | `.config/yabai/yabairc` |
| SKHD | `.config/skhd/skhdrc` |
| Tmux | `tmux/tmux.conf` |
| Lazygit | `.config/lazygit/config.yml` |
| Zsh | `zsh/zshrc.sh` (main), `zsh/zshrc_manager.sh` (entry point) |
| Starship | `.config/starship.toml` |
| IDEVim | `.ideavimrc` |
| PowerShell | `.config/powershell/Microsoft.PowerShell_profile.ps1` |
| Zed | `zed/settings.json`, `zed/keymap.json` |
