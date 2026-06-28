# AGENTS.md

Guidance for agentic coding tools (Claude Code, Codex, Cursor, opencode, …) working in this repository. `CLAUDE.md` is a one-line `@AGENTS.md` import of this file, so every agent reads the same source.

This is a personal dotfiles repository managing configurations for a complete development environment across macOS, Linux, and Windows. It emphasizes terminal-based tools, modal (vim) editing, and tiling window managers.

## Repository Overview

Terminal-centric configs, one repo, three OSes. Core stack:

- **Editors**: Neovim (LazyVim), IdeaVim, Zed
- **Terminals**: Wezterm; Tmux (macOS/Linux only)
- **Window managers**: Yabai + Hammerspoon (macOS), Komorebi (Windows)
- **Shell**: Zsh (custom `zshrc_manager.sh` entry point + `zshrc.sh`)
- **Utilities**: Yazi (files), Lazygit, Starship (prompt), Zoxide (`cd`)

There is **no build/test system** — it's a configuration repo. "Validation" means syntax-checking scripts and verifying symlinks/configs load.

## Setup & Validation

**Deploy (installs packages, creates symlinks, sets env vars):**

```powershell
# Windows — run as Administrator in PowerShell 7+
.\deploy_windows.ps1                 # full: packages, symlinks, env vars
.\deploy_windows.ps1 -SkipPackages   # symlinks only
.\deploy_windows.ps1 -DryRun         # preview, no changes
```

```bash
./setup_mac.sh    # macOS: Homebrew packages, symlinks, services
./deploy.sh       # Linux/macOS universal: deps, oh-my-zsh, symlinks
```

Deploy scripts are **idempotent** — safe to re-run; they back up existing configs and support `-DryRun` where available. Never hardcode absolute paths; use `$HOME`, `$XDG_CONFIG_HOME`, `$env:APPDATA`.

**Validate changes:**

```bash
bash -n script.sh && shellcheck script.sh    # shell scripts
nvim -c ':Lazy sync' -c ':checkhealth'        # Neovim plugins + health
```

```powershell
Get-Command -Syntax .\deploy_windows.ps1      # PowerShell syntax
```

After editing: test the actual symlink creation, source shell configs to confirm no errors, and verify symlink targets still match the tables below.

## Architecture

### Windows Symlink Mappings

| Source | Target |
|--------|--------|
| `.config/nvim` | `$HOME\.config\nvim` |
| `.config/wezterm` | `$HOME\.config\wezterm` |
| `.config/windows-terminal/catppuccin-frappe.json` | `$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\catppuccin-frappe.json` (Catppuccin Frappé color scheme; **both** WT stable + Preview read this edition-agnostic fragments dir, so one file themes both; select it once per app via Settings → Defaults → Color scheme — deploy never touches `settings.json`) |
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
| `claude/` (settings.json, agents, commands, hooks, skills, themes, statusline*) | `$HOME\.claude\…` |
| `.config/opencode/opencode.jsonc` | `$HOME\.config\opencode\opencode.jsonc` |

**Environment Variables (set by deploy script):** `XDG_CONFIG_HOME` → `$HOME\.config`; `KOMOREBI_CONFIG_HOME` → `$HOME\.config\komorebi`.

### Platform-Specific Workflows

**macOS/Linux:** Tmux-centric workflow

- Tmux for terminal multiplexing with TPM plugin manager
- vim-tmux-navigator for Ctrl+hjkl navigation across tmux panes and vim splits
- Zsh auto-attaches to tmux session (skipped in IDE terminals)

**Windows:** Wezterm-centric workflow (no tmux)

- Wezterm workspaces replace tmux sessions (create/switch: `Leader+w` by name, `Leader+f` fuzzy, `Leader+Shift+S` list, `Leader+(`/`Leader+)` cycle)
- **Persistence:** a local `wezterm-mux-server` (unix domain `unix`) keeps shells + their live processes alive across closing WezTerm; **reattach by reopening WezTerm** (auto-connects via `default_gui_startup_args`, non-WSL only), or `wezterm connect unix`. `Leader+d` detaches; closing the window detaches silently (`window_close_confirmation='NeverPrompt'`). Does NOT survive a reboot. Zellij stays opt-in via the `zj` wrapper for the gaps (any-terminal/SSH attach, reboot-restore). Requires WezTerm nightly. The Claude badge/focus cache is namespaced by the stable mux socket tag `sock` (see `[[WezTerm Multiplexer Persistence on Windows]]`).
- Leader key: `Ctrl+Space` (1 second timeout)
- vim-smart-splits plugin enables Ctrl+hjkl navigation between Wezterm panes and Neovim splits
- Key bindings: `Leader+v` (hsplit), `Leader+s` (vsplit), `Leader+x` (close pane), `Leader+t` (new tab), `Leader+d` (detach mux), `Leader+1-9` (switch tabs)

### Window Management

- **macOS:** Yabai (tiling) + **Hammerspoon** (Hyper/Meh hotkeys + resize/service modes + OSD + **stackline** stacking overlay — floating per-window pills with app icons, Frappe Mauve focus; skhd retired) + SketchyBar (status bar)
- **Windows:** Komorebi (tiling) + per-monitor status bars. Start with `komorebic start`. Config requires `KOMOREBI_CONFIG_HOME` env var pointing to `$HOME\.config\komorebi`

### Editor Stack

- **Neovim:** LazyVim framework with Lazy.nvim plugin manager. `.config/nvim/init.lua` bootstraps LazyVim; plugins in `.config/nvim/lua/plugins/` (one file per plugin group); run `:Lazy sync` after install.
- **Wezterm:** Primary terminal, Lua config at `.config/wezterm/wezterm.lua`
- **Claude Code skills:** `~/.claude/skills` is a **real directory**, not a whole-dir symlink. Repo skills under `claude/skills/` are linked in **per-item** by `scripts/lib/link-skills.sh` (called from `scripts/sync-ai-configs.sh`; Windows does the same in `deploy_windows.ps1`). This leaves room to install public skills with `npx skills add -g <github-repo>` — they land in `~/.claude/skills/<name>` outside the dotfiles repo. Edit your own skills in `claude/skills/`; they're live via the symlink. A public skill that shares a repo skill's name wins (the repo skill is skipped).

### Shell Configuration

Zsh loads via `zshrc_manager.sh` which:

1. Detects IDE terminals (IntelliJ, VSCode, Cursor) and skips tmux attachment
2. Sources `zshrc.sh` for aliases, plugins, and environment setup
3. Auto-attaches to tmux session outside IDEs (macOS/Linux only)

Key aliases: `y` (yazi with cd-on-exit), `cd` (aliased to zoxide `z`), `ls/ll/la/lt` (eza variants).

### Cross-Tool Integration

- **Navigation:** Ctrl+hjkl works across tmux/wezterm panes and vim splits
- **Theme:** Catppuccin Frappe used consistently (wezterm, tmux, yazi, komorebi)
- **Font:** JetBrains Mono Nerd Font
- **Notifications (Windows):** clicking a Claude Code desktop toast focuses the exact WezTerm window/workspace/tab/pane that fired it. The `claude-wez://` URL-protocol handler drops a one-shot focus-request file (`~/.cache/claude-notify/wezterm-focus/<mux>/<pane>`, UTC-epoch body, 60s TTL) that `wezterm.lua` consumes on its next status tick and raises natively — `wezterm cli` cannot focus across windows on Windows, so the GUI Lua API is the only reliable path. `deploy_windows.ps1` installs the `BurntToast` module and registers the handler as `wscript.exe → claude/hooks/bin/claude-wez-launch.vbs` (windowless, so clicking never flashes Windows Terminal). Distinct from the tab-badge alert channel (`wezterm-alerts/`).

| Toast-click focus file | Purpose |
|------------------------|---------|
| `claude/hooks/bin/claude-notify.ps1` | Toast emit + `-Activate` URI handler (writes the focus-request file). URI guard: pane `^\d+$`, mux `^[A-Za-z0-9_-]+$` (blocks path traversal). |
| `claude/hooks/bin/claude-wez-launch.vbs` | Windowless launcher (`wscript` → hidden pwsh; avoids a terminal flash) |
| `.config/wezterm/wezterm_claude_focus.lua` | Pure focus module (`dir`/`mux_tag`/`pending` helpers, unit-tested) |
| `.config/wezterm/wezterm.lua` | Focus consumption (status-tick poll → `set_active_workspace`/`activate`/`focus`) |

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

**Hooks & commands** (all under `claude/`, symlinked into `~/.claude/` at deploy — active immediately, no separate install):

| Purpose | Path |
|---------|------|
| PostToolUse ledger (counts work signals) | `claude/hooks/session-ledger.sh` |
| Stop-hook nudge (prompts `/close` when threshold crossed) | `claude/hooks/session-capture-stop.sh` |
| SessionStart continuity read-back | `claude/hooks/continuity-readback.sh` |
| Marks ledger captured after `/close` runs | `claude/hooks/ledger-mark-captured.sh` |
| Shared ledger logic | `claude/hooks/lib/session-ledger-lib.sh` |
| `/close` command definition | `claude/commands/close.md` |
| `close-session` skill (distils session → Wiki + continuity) | `claude/skills/close-session/SKILL.md` |
| One-time vault git init | `scripts/init-vault-git.sh` |

Design spec: `docs/superpowers/specs/2026-06-15-automated-session-memory-protocol-design.md`. Implementation plan: `docs/superpowers/plans/2026-06-15-automated-session-memory-protocol.md`. Phase 1 (shipped) = ledger + `Stop` nudge + `/close` + continuity read-back + `git init`; `PreCompact` force, fallback reconcile, and headless capture are Phase 2/3.

## Code Style

`.editorconfig` is authoritative (insert final newline, LF line endings everywhere). Key rules:

- **Lua** (Neovim/Wezterm): 4-space indent, ≤120 cols, `snake_case`, stylua-compatible. LuaLS annotations (`---@param`) on complex functions; `pcall()` in critical paths. Layout: `init.lua` bootstraps, `lua/config/` core (options/keymaps/autocmds), `lua/plugins/` one file per plugin group.
- **Shell** (bash/zsh): 2-space indent, quote every expansion (`"$var"`), guard with `[ -x "$(command -v prog)" ]` / `[ -f "$file" ]`, `set -e` for fail-fast.
- **PowerShell**: 2-space indent, comment-based help header, typed/`[switch]` params, `try/catch`, `#Requires -RunAsAdministrator` (or manual check) where needed.
- **JSON/TOML**: 2-space indent; follow the TOML spec strictly.

No `.cursorrules` or `.github/copilot-instructions.md` exist — this file is the single guide.

## Important Patterns

**Platform detection (Lua):**

```lua
if vim.fn.has("win32") == 1 then       -- Windows
elseif vim.fn.has("mac") == 1 then     -- macOS
else                                    -- Linux
end
```

**VSCode keymaps (OCP):** configuration-driven editor-variant detection (Cursor, Antigravity, VSCode) with automatic fallback to VSCode defaults. When adding commands or variants, follow `docs/VSCODE_KEYMAPS_OCP_REFACTORING.md`.

## Key Paths

| Tool / purpose | Path |
|----------------|------|
| Neovim | `.config/nvim/` (`init.lua` bootstraps LazyVim; plugins in `lua/plugins/`) |
| Wezterm | `.config/wezterm/wezterm.lua` |
| Tmux (macOS/Linux) | `tmux/tmux.conf` |
| Zsh | `zsh/zshrc.sh` (main) + `zsh/zshrc_manager.sh` (entry point) |
| Starship | `.config/starship.toml` |
| Yazi / Lazygit | `.config/yazi/`, `.config/lazygit/config.yml` |
| Komorebi (Windows) | `.config/komorebi/komorebi.json` |
| YASB (Windows status bar) | `.config/yasb/config.yaml` + `styles.css` (reload: `yasbc reload`) |
| Yabai (macOS) | `.config/yabai/yabairc`; signal/helper scripts `.config/yabai/scripts/` |
| Hammerspoon (macOS) | `.config/hammerspoon/` (→ `~/.hammerspoon`) |
| stackline (macOS) | `.config/hammerspoon/stackline/` (vendored `poddarh` fork) + `stackline_config.lua` (Frappe overrides); notes `docs/superpowers/stackline-fork-notes.md` |
| Kanata (macOS) | `.config/kanata/kanata.kbd` (+ `dev.kanata.kanata.plist`) |
| Zed | `zed/settings.unix.json` (mac/Linux), `zed/settings.windows.json` (Windows), `zed/keymap.json` |
| IdeaVim | `.ideavimrc` |
| PowerShell | `.config/powershell/Microsoft.PowerShell_profile.ps1` |
| Claude Code | `claude/` → `~/.claude/` |
| Claude skills linker (mac/Linux) | `scripts/lib/link-skills.sh` (called by `scripts/sync-ai-configs.sh`) |
| Global agent instructions | `claude/AGENTS.md` (distinct from this repo-root file) → `~/.claude/{CLAUDE,AGENTS}.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md` (Cursor: `scripts/copy-agents-rules.sh`) |
| opencode | `.config/opencode/opencode.jsonc` |
| Secrets (gitignored) | `~/.config/dotfiles/secrets.env` (template: `secrets.env.example`) |
