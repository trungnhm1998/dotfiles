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

## Updating an existing machine

Configs are **symlinked** into this repo, so most updates need only a pull:

```bash
cd ~/dotfiles && git pull
```

This instantly updates every symlinked config (Neovim, Wezterm, Tmux, Zsh, Claude Code, etc.) — no re-deploy needed. Re-run a script only for the non-symlink bits:

| When | Run |
|------|-----|
| AI configs / MCP / secrets changed | `./scripts/sync-ai-configs.sh` (Linux/macOS) · `.\deploy_windows.ps1 -SkipPackages` (Windows) |
| New tool or package added | `./deploy.sh` (Linux/macOS) · `./setup_mac.sh` (macOS) · `.\deploy_windows.ps1 -SkipPackages` (Windows) |
| Neovim plugins out of date | open `nvim` → `:Lazy sync` |
| Tmux plugins out of date | `Prefix + I` (Prefix = `Ctrl+Space`) |

> First sync on a new machine creates `~/.config/dotfiles/secrets.env` from the template — edit it and fill in `CONTEXT7_API_KEY`.

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

## Keyboard Remapping (Kanata)

The MacBook built-in keyboard is remapped with [Kanata](https://github.com/jtroo/kanata) to mirror the ZSA Voyager layout (config: `.config/kanata/kanata.kbd`, single source). The external Voyager is never touched — its firmware does its own remapping.

- **Caps Lock** → tap `Esc` / hold `Ctrl` (fixes Karabiner's tap-Esc misfires under Alfred)
- **Home-row mods** (C-S-A-G): `A/S/D/F` = Ctrl/Shift/Alt/Cmd, `J/K/L/;` mirrored, with opposite-hand resolution so same-hand rolls stay letters. For same-hand combos (e.g. Cmd+Q), use the **opposite** hand's mod.
- **Z/X/./?** → Hyper/Meh; **Right Option** → Hyper.
- **Hold Space** → nav layer: `hjkl` = arrows, `Y/U/I/O` = Home/PgDn/PgUp/End; combine with the live left-hand mods for select / word / line motions.
- **Panic exit:** `LCtrl+Space+Esc`.

**One-time setup (macOS):** install the pqrs Karabiner-DriverKit-VirtualHIDDevice driver (v6.2.0, pinned in kanata's `setup-macos.md`), then activate it via the **hidden** Manager app — `sudo "/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" forceActivate` (note the leading dot in `.Karabiner…`) — and enable it under System Settings → General → Login Items & Extensions → Driver Extensions. Grant Input Monitoring + Accessibility to `/opt/homebrew/bin/kanata`. **Two** root LaunchDaemons must be installed (commands in `setup_mac.sh`): `org.pqrs.Karabiner-VirtualHIDDevice-Daemon` (the driver daemon kanata connects to — **required**; Karabiner-Elements used to run it implicitly, so don't skip it once KE is gone) and `dev.kanata.kanata` (kanata itself). Reload after edits with `scripts/kanata-reload.sh`.

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
| Claude Code | AI agent config + skills | `claude/` |
| Kanata | Keyboard remap (macOS built-in kbd) | `.config/kanata/kanata.kbd` |

## Claude Code Skills

Canonical store: `claude/skills/<name>/` - one directory per skill, linked into `~/.claude/skills/`:

- **Windows** (`deploy_windows.ps1`): per-item symlinks, so plugin-managed junctions in `~/.claude/skills/` are never clobbered. New repo skills get linked on the next deploy; existing names are left as-is.
- **macOS/Linux** (`scripts/sync-ai-configs.sh`, called by `deploy.sh`): whole-dir symlink `~/.claude/skills -> claude/skills`, so new repo skills are live immediately after pull.

Current skills: `game-feel`, `game-marketing`, `gamedev-art`, `gamedev-audio`, `handoff`, `indie-production`, `level-design`, `unity-engineering`, `unity-shaders`, `unity-worktree-setup`.

`unity-worktree-setup` is script-driven (designed to run on smaller/faster models) and dual-runtime: the same five worktree lifecycle verbs (`preflight`, `list-worktrees`, `new-worktree`, `recycle-worktree`, `remove-worktree`) exist as PowerShell (`scripts/*.ps1`, Windows) and bash 3.2 (`scripts/*.sh`, macOS/Linux - no PowerShell required). Both emit identical JSON and exit codes.

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed comparison of deployment scripts
- **[STRUCTURE.md](STRUCTURE.md)** - Explanation of repository organization
- **[CLAUDE.md](CLAUDE.md)** - Complete architecture documentation for AI assistants
- **[docs/CROSS_PLATFORM_CLAUDE_CONFIG.md](docs/CROSS_PLATFORM_CLAUDE_CONFIG.md)** - How the shared Claude Code config (vault path, hooks, agent-flow) stays portable across macOS/Windows

## Common Aliases

- `y` - Yazi file manager with cd-on-exit
- `z` - Zoxide smart directory jumping (aliased to `cd`)
- `ls`, `ll`, `la`, `lt` - Eza variants (modern ls replacement)

## License

Personal configuration files - use at your own discretion.
