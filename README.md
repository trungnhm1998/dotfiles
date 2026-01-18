# dotfiles

Personal dotfiles for a complete development environment across macOS, Linux, and Windows. Focused on terminal-based tools, modal (vim) editing, and tiling window managers.

## Features

- **Cross-Platform Support**: Optimized deployment for Windows, macOS, and Linux
- **Modern XDG Compliance**: Configurations organized in `.config/` directory
- **Unified Theme**: Catppuccin Frappe across all tools (Neovim, Wezterm, Tmux, Yazi, Komorebi)
- **Modal Editing**: Neovim with LazyVim + IdeaVim for JetBrains IDEs
- **Seamless Navigation**: Ctrl+hjkl works across terminal multiplexer panes and vim splits
- **Tiling Window Managers**: Yabai (macOS) and Komorebi (Windows)

## Quick Start

Choose the deployment script for your platform:

### Windows (PowerShell 7+ as Administrator)

```powershell
.\deploy_windows.ps1              # Full setup: packages, symlinks, env vars
.\deploy_windows.ps1 -SkipPackages  # Symlinks only
.\deploy_windows.ps1 -DryRun        # Preview changes without executing
```

### macOS

```bash
./setup_mac.sh  # Installs Homebrew packages, creates symlinks, starts services
```

### Linux / macOS (Universal)

```bash
./deploy.sh  # Installs dependencies, oh-my-zsh, creates symlinks
```

## Platform-Specific Workflows

### Windows
- **Terminal**: Wezterm with workspaces (replaces tmux)
- **Navigation**: vim-smart-splits for pane/split navigation
- **Window Manager**: Komorebi with per-monitor status bars
- **Leader Key**: `Ctrl+Space` (1 second timeout)

### macOS/Linux
- **Terminal**: Wezterm or Alacritty
- **Multiplexer**: Tmux with TPM plugin manager
- **Navigation**: vim-tmux-navigator for pane/split navigation
- **Window Manager**: Yabai (macOS) with SKHD hotkeys and SketchyBar

## Prerequisites

- **Git** (all platforms)
- **Windows**: PowerShell 7+, Admin privileges
- **macOS**: Xcode Command Line Tools
- **Linux**: curl, zsh
- **Font**: JetBrains Mono Nerd Font (installed by deployment scripts)

## Post-Installation

1. **Restart your shell** or source the new configuration:
   - Zsh: `source ~/.zshrc`
   - PowerShell: `. $PROFILE`

2. **Neovim**: Launch nvim and run `:Lazy sync` to install plugins

3. **Tmux** (macOS/Linux): Press `Prefix + I` to install TPM plugins (Prefix = `Ctrl+Space`)

4. **Komorebi** (Windows): Start with `komorebic start` after setting `KOMOREBI_CONFIG_HOME` env var

## Key Tools

| Tool | Purpose | Config Location |
|------|---------|-----------------|
| Neovim | Editor | `.config/nvim/` |
| Wezterm | Terminal | `.config/wezterm/wezterm.lua` |
| Tmux | Multiplexer | `tmux/tmux.conf` |
| Zsh | Shell | `zsh/zshrc.sh` |
| Komorebi | Window Manager (Windows) | `.config/komorebi/` |
| Yabai | Window Manager (macOS) | `.config/yabai/yabairc` |
| Yazi | File Manager | `.config/yazi/` |
| Starship | Prompt | `.config/starship.toml` |
| IdeaVim | Vim for JetBrains | `.ideavimrc` |

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed comparison of deployment scripts
- **[STRUCTURE.md](STRUCTURE.md)** - Explanation of repository organization
- **[CLAUDE.md](CLAUDE.md)** - Complete architecture documentation for AI assistants

## Common Aliases

- `y` - Yazi file manager with cd-on-exit
- `z` - Zoxide smart directory jumping (aliased to `cd`)
- `ls`, `ll`, `la`, `lt` - Eza variants (modern ls replacement)

## License

Personal configuration files - use at your own discretion.
