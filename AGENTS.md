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
| `.config/windows-terminal/settings.json` | `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` **and** `...\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json` (one shared settings file for both WT editions; Frappe scheme embedded in `schemes`; WT writes through the symlink, so UI edits in either edition show up in `git diff`; the old `Fragments\dotfiles` theme fragment is retired and removed by deploy) |
| `.config/komorebi` | `$HOME\.config\komorebi` |
| `.config/kanata` | `$HOME\.config\kanata` (Kanata 60%-keyboard remapper; **Windows uses `kanata.win.kbd`** — the macOS `kanata.kbd` has `fn`/media keys that won't compile here. Driver-free LLHOOK; "gaming" = `kanata.exe` stopped. Toggle: YASB `kanata_toggle` pill, `Hyper+G`, or service-mode `g` (both). Autostarts via a logon Scheduled Task.) |
| `.config/yasb` | `$HOME\.config\yasb` (Windows status bar; reload with `yasbc reload`) |
| `.config/zellij` | `$HOME\.config\zellij` (via `ZELLIJ_CONFIG_DIR`; note: layout pickers need `layout_dir` set in config.kdl — Zellij's `read_dir` won't enumerate custom layouts through a Windows symlink) |
| `.config/psmux` | `$HOME\.config\psmux` (psmux — native-Windows tmux; reads tmux-syntax config but **not** TPM plugins. Launch via `tmux`/`psmux`/`pmux` from the pwsh profile, which sets the `mux_prog=psmux` user var so `wezterm.lua` hands over `Ctrl+Space`. Manual launch only — no auto-attach.) |
| `.config/yazi` | `$env:APPDATA\yazi\config` (note: different from XDG) |
| `.config/lazygit` | `$env:APPDATA\lazygit` |
| `.config/starship.toml` | `$HOME\.config\starship.toml` |
| `.config/powershell/Microsoft.PowerShell_profile.ps1` | `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `.ideavimrc` | `$HOME\.ideavimrc` |
| `zed/settings.windows.json` | `$env:APPDATA\Zed\settings.json` |
| `zed/keymap.json` | `$env:APPDATA\Zed\keymap.json` |
| `claude/AGENTS.md` (canonical global agent instructions) | `$HOME\.claude\CLAUDE.md`, `$HOME\.claude\AGENTS.md`, `$HOME\.codex\AGENTS.md`, `$HOME\.config\opencode\AGENTS.md`, `$HOME\.pi\agent\AGENTS.md`, `$HOME\.copilot\copilot-instructions.md` (Copilot's native personal-instructions filename — not `AGENTS.md`) |
| `claude/` (settings.json, agents, commands, hooks, skills, themes) | `$HOME\.claude\…` |
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
- **psmux** (native-Windows tmux) is a **manual-launch** mux for Claude Code agent-team panes — type `tmux`/`psmux`/`pmux` (pwsh wrappers) to start it. It reads `.config/psmux/psmux.conf` (portable tmux keybindings; TPM plugins unsupported), and its `Ctrl+Space` prefix is handed over by `wezterm.lua` via the `mux_prog=psmux` user var (same yield as Zellij/ssh/wsl). No auto-attach; distinct from the WezTerm-mux default lane and opt-in Zellij.

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

## Vault RAG-lite (Obsidian wiki recall)

Two hooks ground every session in Max's Obsidian vault (per-machine path resolved by `claude/hooks/lib/obsidian-vault.sh`; override with `$OBSIDIAN_VAULT`). Expected absence (no vault/index on a machine) is silent; if the vault resolves but injection breaks, `vault-map.sh` injects a ⚠ warning — never silence.

| Purpose | Path |
|---------|------|
| SessionStart **slim map** — derives a titles-only catalog from `05.Wiki/index.md` (Maps hubs keep summaries; ~3K tokens) and injects it. Content streams through `jq -Rs`, never argv (a 101KB index once blew the ~32KB MSYS limit silently). | `claude/hooks/vault-map.sh` |
| UserPromptSubmit **recall** — on recall-shaped prompts ("what did I…", "I/we tried/built/set up…"), ripgrep-searches the vault and injects ranked note titles as leads (title matches outrank body matches; sensitive-looking files excluded). | `claude/hooks/vault-recall.sh` |

Tests: `claude/hooks/tests/test-vault-{map,recall}.sh`; run all with `bash claude/hooks/tests/run-tests.sh`.

Capture is manual: `/wiki-capture` (`claude/commands/wiki-capture.md`) files durable knowledge from a session into `05.Wiki/`. (The automated Session Memory Protocol — `/close`, session ledger, continuity read-back — was retired 2026-07-02; see git history if resurrecting.)

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
| Kanata (Windows) | `.config/kanata/kanata.win.kbd` (config) · `.config/kanata/kanata-toggle.ps1` (start/stop/`-State`/`-Off`) |
| Yabai (macOS) | `.config/yabai/yabairc`; signal/helper scripts `.config/yabai/scripts/` |
| Hammerspoon (macOS) | `.config/hammerspoon/` (→ `~/.hammerspoon`) |
| stackline (macOS) | `.config/hammerspoon/stackline/` (vendored `poddarh` fork) + `stackline_config.lua` (Frappe overrides); notes `docs/superpowers/stackline-fork-notes.md` |
| Kanata (macOS) | `.config/kanata/kanata.kbd` (+ `dev.kanata.kanata.plist`) |
| Zed | `zed/settings.unix.json` (mac/Linux), `zed/settings.windows.json` (Windows), `zed/keymap.json` |
| IdeaVim | `.ideavimrc` |
| PowerShell | `.config/powershell/Microsoft.PowerShell_profile.ps1` |
| Claude Code | `claude/` → `~/.claude/` |
| Ad-hoc MCP configs | `claude/mcp/<name>.json` — rare-use servers (e.g. figma), launched per-session via the pwsh `ccmcp <name> [<name>…]` function (`claude --mcp-config`) |
| Claude skills linker (mac/Linux) | `scripts/lib/link-skills.sh` (called by `scripts/sync-ai-configs.sh`) |
| Global agent instructions | `claude/AGENTS.md` (distinct from this repo-root file) → `~/.claude/{CLAUDE,AGENTS}.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`, `~/.pi/agent/AGENTS.md`, `~/.copilot/copilot-instructions.md` (Cursor: `scripts/copy-agents-rules.sh`, or `Copy-AgentsRules`/`ccrules` on Windows) |
| opencode | `.config/opencode/opencode.jsonc` |
| Secrets (gitignored) | `~/.config/dotfiles/secrets.env` (template: `secrets.env.example`) |
