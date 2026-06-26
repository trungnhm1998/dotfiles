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
| `.config/yasb` | `$HOME\.config\yasb` (Windows status bar; reload with `yasbc reload`) |
| `.config/zellij` | `$HOME\.config\zellij` (via `ZELLIJ_CONFIG_DIR`; note: layout pickers need `layout_dir` set in config.kdl — Zellij's `read_dir` won't enumerate custom layouts through a Windows symlink) |
| `.config/yazi` | `$env:APPDATA\yazi\config` (note: different from XDG) |
| `.config/lazygit` | `$env:APPDATA\lazygit` |
| `.config/starship.toml` | `$HOME\.config\starship.toml` |
| `.config/powershell/Microsoft.PowerShell_profile.ps1` | `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `.ideavimrc` | `$HOME\.ideavimrc` |
| `zed/settings.windows.json` | `$env:APPDATA\Zed\settings.json` |
| `zed/keymap.json` | `$env:APPDATA\Zed\keymap.json` |
| `claude/AGENTS.md` (canonical global agent instructions) | `$HOME\.claude\CLAUDE.md`, `$HOME\.claude\AGENTS.md`, `$HOME\.codex\AGENTS.md`, `$HOME\.config\opencode\AGENTS.md` |
| `claude/` (settings.json, agents, commands, hooks, skills, statusline*) | `$HOME\.claude\…` |
| `.config/opencode/opencode.jsonc` | `$HOME\.config\opencode\opencode.jsonc` |

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

## Session Memory Protocol (automated close-session capture)

Keeps the Obsidian `05.Wiki` and per-project continuity notes current with minimal prompting. A deterministic per-session **ledger** (`~/.claude/.session-ledger/<id>.json`, maintained by `claude/hooks/session-ledger.sh` on `PostToolUse`) counts work signals (files written/edited, git commits, PRs). When uncaptured work crosses a threshold, the `Stop` hook (`claude/hooks/session-capture-stop.sh`) injects an escalating nudge to run `/close`.

**`/close`** (the `close-session` skill) distils the session into two channels:
- **Durable knowledge → `05.Wiki/`** — git-committed as an audit trail of agent-authored files.
- **Continuity → `<project>/.planning/continuity.md`** — changes, decisions made, decisions pending, next steps; surfaced at the next `SessionStart` by `claude/hooks/continuity-readback.sh`.

It then resets the ledger via `claude/hooks/ledger-mark-captured.sh`.

**Activation (first time, per machine):**
1. Deploy so the hooks/skill/command symlink into `~/.claude`: `.\deploy_windows.ps1 -SkipPackages` (Windows, admin) or `./deploy.sh` (macOS/Linux).
2. Put the vault under local git (audit trail): `bash scripts/init-vault-git.sh`. Only `.gitignore` is committed initially; existing notes stay untracked — the history is intentionally a precise audit of agent-written files, not a vault snapshot.
3. Verify: edit a few files / commit in any project, then run `/close` — it should write + commit to `05.Wiki` and create/refresh `<project>/.planning/continuity.md`.

Disable anytime with `WIKI_AUTO=0`. Run the hook tests with `bash claude/hooks/tests/run-tests.sh`.

**Toggles (environment variables):**

| Var | Default | Status | Effect |
|-----|---------|--------|--------|
| `WIKI_AUTO` | `1` | active | Master kill-switch for the whole protocol. |
| `WIKI_THRESHOLD_FILES` | `3` | active | Files-touched delta that counts as "meaningful". |
| `WIKI_THRESHOLD_COMMITS` | `1` | active | Commits delta that counts as "meaningful". |
| `WIKI_AUTORUN` | `0` | Phase 2 | Force a `Stop`-block capture after ignored nudges. |
| `WIKI_FALLBACK` | `1` | Phase 2 | Next-`SessionStart` reconciliation of walk-away sessions. |
| `WIKI_FALLBACK_HEADLESS` | `0` | Phase 3 | Experimental background `claude -p` capture. |

Design spec: `docs/superpowers/specs/2026-06-15-automated-session-memory-protocol-design.md`. Implementation plan: `docs/superpowers/plans/2026-06-15-automated-session-memory-protocol.md`. Phase 1 (shipped) = ledger + `Stop` nudge + `/close` + continuity read-back + `git init`; `PreCompact` force, fallback reconcile, and headless capture are Phase 2/3.

## Key Configuration Files

| Tool | Config Location |
|------|-----------------|
| Neovim | `.config/nvim/` |
| Wezterm | `.config/wezterm/wezterm.lua` |
| Komorebi | `.config/komorebi/komorebi.json` |
| YASB (Windows status bar) | `.config/yasb/config.yaml` + `.config/yasb/styles.css` |
| Yabai | `.config/yabai/yabairc` |
| SKHD | `.config/skhd/skhdrc` |
| Tmux | `tmux/tmux.conf` |
| Lazygit | `.config/lazygit/config.yml` |
| Zsh | `zsh/zshrc.sh` (main), `zsh/zshrc_manager.sh` (entry point) |
| Starship | `.config/starship.toml` |
| IDEVim | `.ideavimrc` |
| Kanata (keyboard remap, macOS) | `.config/kanata/kanata.kbd` (+ `dev.kanata.kanata.plist`) |
| PowerShell | `.config/powershell/Microsoft.PowerShell_profile.ps1` |
| Zed | `zed/settings.unix.json` (macOS/Linux), `zed/settings.windows.json` (Windows), `zed/keymap.json` |
| Global agent instructions | `claude/AGENTS.md` → `~/.claude/CLAUDE.md` + `~/.claude/AGENTS.md` + `~/.codex/AGENTS.md` + `~/.config/opencode/AGENTS.md` (Cursor: paste into User Rules via `scripts/copy-agents-rules.sh`) |
| Claude Code | `claude/` → `~/.claude/` |
| opencode | `.config/opencode/opencode.jsonc` |
| Secrets (gitignored) | `~/.config/dotfiles/secrets.env` (template: `secrets.env.example`) |
