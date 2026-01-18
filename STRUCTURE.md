# Repository Structure

This dotfiles repository uses a **dual organization paradigm** that combines modern XDG standards with traditional Unix dotfile conventions. This design is intentional and serves specific purposes.

## Directory Overview

```
dotfiles/
├── .config/              # Modern XDG-compliant configurations (96 files)
│   ├── nvim/            # Neovim with LazyVim
│   ├── wezterm/         # Wezterm terminal
│   ├── komorebi/        # Windows tiling WM
│   ├── yabai/           # macOS tiling WM
│   ├── yazi/            # File manager
│   ├── lazygit/         # Git TUI
│   ├── starship.toml    # Shell prompt
│   └── powershell/      # PowerShell profile
├── tmux/                # Traditional location for tmux configs
│   └── tmux.conf
├── vim/                 # Legacy vim configurations
├── zsh/                 # Zsh shell configurations
│   ├── zshrc.sh         # Main config
│   └── zshrc_manager.sh # Entry point
├── .ideavimrc           # IdeaVim (JetBrains) config
└── deploy scripts       # Platform-specific installers
```

## Why Two Paradigms?

### XDG Base Directory Specification (.config/)

**Purpose**: Modern standard for organizing user configurations

**Location**: `~/.config/` on Unix, `$HOME\.config\` on Windows

**Tools using XDG**:
- Neovim (`nvim` expects `~/.config/nvim/`)
- Wezterm (respects `XDG_CONFIG_HOME`)
- Yazi, Lazygit, Starship (modern CLI tools)
- Komorebi, Yabai (window managers)

**Benefits**:
- Keeps home directory clean
- Portable across platforms
- Standard expected by modern tools
- Easier to backup/sync (single directory)

### Traditional Unix Structure (root-level)

**Purpose**: Compatibility with legacy tools and deployment scripts

**Location**: Root of repository, symlinked to `~/`

**Tools using traditional structure**:
- Tmux (expects `~/.tmux.conf`)
- Vim (expects `~/.vimrc` or `~/.vim/`)
- Zsh (expects `~/.zshrc`)
- Oh-My-Zsh (installed to `~/.oh-my-zsh`)

**Why not move these into `.config/`?**
1. **Deployment script expectations**: All three deployment scripts reference these paths directly
2. **Tool compatibility**: Tmux and traditional vim don't support XDG by default
3. **Community conventions**: Most dotfile repositories follow this pattern
4. **Symlink simplicity**: Easier to symlink `~/dotfiles/tmux/tmux.conf` → `~/.tmux.conf`

## How Deployment Scripts Handle This

### Windows (deploy_windows.ps1)
- Symlinks `.config/*` → `$HOME\.config\*`
- Symlinks `.ideavimrc` → `$HOME\.ideavimrc`
- Sets `XDG_CONFIG_HOME` environment variable
- PowerShell profile goes to `$HOME\Documents\PowerShell\`

### macOS (setup_mac.sh)
- Symlinks `.config/*` → `~/.config/*`
- Symlinks `tmux/tmux.conf` → `~/.tmux.conf`
- Symlinks `zsh/zshrc_manager.sh` → `~/.zshrc`
- Symlinks `.ideavimrc` → `~/.ideavimrc`

### Universal (deploy.sh)
- Same as macOS approach
- Works on Linux and macOS

## File Count Distribution

| Location | Files | Percentage | Purpose |
|----------|-------|------------|---------|
| `.config/` | 96 | 84% | Modern tool configurations |
| Root-level | 18 | 16% | Traditional configs + scripts |

The `.config/` directory dominates because modern tools have more complex configurations (Neovim plugins, Wezterm keybindings, etc.).

## Special Cases

### Neovim
- **Location**: `.config/nvim/`
- **Why**: Neovim only looks in `~/.config/nvim/`, not `~/.vim/`
- **Old vim/**: Legacy configs, kept for reference or fallback

### Zsh
- **Location**: Root-level `zsh/`
- **Reason**: Entry point `~/.zshrc` must be in home directory
- **Structure**: `~/.zshrc` symlinks to `zshrc_manager.sh`, which sources `zshrc.sh`

### Yazi
- **Location**: `.config/yazi/`
- **Special**: Contains vendored themes and plugins (see [EXTERNAL_DEPS.md](.config/yazi/EXTERNAL_DEPS.md))
- **Windows**: Symlinked to `$env:APPDATA\yazi\config` (different from Unix)

### IdeaVim
- **Location**: Root-level `.ideavimrc`
- **Reason**: JetBrains IDEs expect `~/.ideavimrc` (no XDG support)
- **Platforms**: Works identically on Windows, macOS, Linux

## Configuration Precedence

Some tools check multiple locations. Here's the resolution order:

### Neovim
1. `~/.config/nvim/init.lua` (XDG)
2. `~/.vimrc` (legacy, ignored if above exists)

### Tmux
1. `~/.tmux.conf` (only location checked)

### Zsh
1. `~/.zshrc` (entry point)
2. Sources additional files from `~/dotfiles/zsh/`

## Adding New Configurations

### For Modern Tools (supports XDG)
1. Add to `.config/<tool-name>/`
2. Update deployment script to symlink it
3. Modern tools will auto-detect via `$XDG_CONFIG_HOME`

### For Traditional Tools
1. Add to root level or dedicated directory (e.g., `tmux/`)
2. Update deployment script to symlink to `~/.<filename>`
3. May need explicit path in tool's config

## Migration Path (If Desired)

Some tools have gained XDG support over time:

**Tmux** (v3.1+):
- Supports `~/.config/tmux/tmux.conf`
- Would require updating all deployment scripts

**Zsh**:
- Supports `$ZDOTDIR` variable
- Would require setting `ZDOTDIR=~/.config/zsh` in `~/.zshenv`

**Not recommended** unless you have specific needs, as it breaks compatibility with standard deployment patterns.

## Best Practices

1. **Don't mix paradigms within a tool**: Keep all of a tool's config in one location
2. **Document exceptions**: If a file must be in a specific location, document why
3. **Update all deployment scripts**: When adding configs, update all three scripts
4. **Test symlinking**: Verify symlinks work on all platforms before committing

## Summary

The dual structure is not a historical accident - it's a deliberate design that:
- Embraces modern XDG standards where possible
- Maintains compatibility with traditional Unix tools
- Simplifies deployment across platforms
- Follows community conventions for discoverability

When in doubt, follow this rule:
- **New tool supports XDG?** → Use `.config/<tool>/`
- **Tool expects `~/.toolrc`?** → Use root level or dedicated directory
