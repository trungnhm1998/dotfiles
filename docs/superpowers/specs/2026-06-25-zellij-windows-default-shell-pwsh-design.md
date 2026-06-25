# Zellij Windows default shell = PowerShell 7 — design

- **Date:** 2026-06-25
- **Status:** Approved design (brainstorming) → pending implementation plan
- **Scope:** Windows only. A focused follow-on to the Zellij adoption (Phase A is already shipped).
- **Related:** `docs/superpowers/specs/2026-06-25-zellij-windows-adoption-design.md`, `docs/superpowers/plans/2026-06-25-zellij-windows-adoption.md`

## Problem / motivation

Phase A of the Zellij adoption shipped a working `config.kdl` (catppuccin-frappe, session
serialization, `Ctrl+Space` tmux mode) and an `agents` layout whose panes pin `command "pwsh"`.
But the base config sets **no `default_shell`**, so any pane *not* spawned by that layout — the
first pane of a plain `zellij` session, panes opened ad-hoc with `n`, new tabs — falls back to
Zellij's Windows default (`$SHELL` is unset on Windows). The goal: **every** new Zellij pane/tab
opens **PowerShell 7 (`pwsh`)**, matching the WezTerm setup so the two terminals behave identically.

## Reference: how WezTerm launches pwsh (the parity target)

`.config/wezterm/wezterm.lua` is the source of truth for "the same" shell on this machine:

- **Binary:** PowerShell 7, resolved to a **full path** — primary `C:\Program Files\PowerShell\7\pwsh.exe`,
  fallback `C:\Program Files\PowerShell\pwsh.exe` (`wezterm.lua:99-104`).
- **Flag:** `-NoLogo`, used in `default_prog` (`:219`), new-tab (`:412`) and new-pane (`:297`) spawns.

So "match WezTerm" = `pwsh 7 (full path) -NoLogo`.

## Decision

**Set `default_shell` in `.config/zellij/config.kdl` to the full path of pwsh 7.** This is Zellij's
canonical mechanism and the only one that covers *all* pane-creation paths (initial pane, `n`-spawned
panes, new tabs) in one declaration.

```kdl
// Default shell for new panes/tabs — match the WezTerm setup (pwsh 7; see wezterm.lua:99-104,219).
// Windows-only today: this config dir is NOT symlinked on macOS/Linux (deploy.sh / setup_mac.sh skip
// zellij), so a Windows path is safe here. If zellij is later adopted on mac/linux, guard this — those
// OSes want $SHELL/zsh. default_shell takes a PATH ONLY: it cannot pass -NoLogo (see "Banner" below).
default_shell "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
```

### Mechanisms rejected

- **`$SHELL` env var (Windows-only, via `deploy_windows.ps1`):** would keep `config.kdl` OS-neutral,
  but `$SHELL` is read by other tools on Windows (git, lazygit, etc.) — unwanted side effects — and
  still can't pass `-NoLogo`. No advantage over `default_shell`, since the config is Windows-only today.
- **Per-layout `command "pwsh"` only:** that's the existing `agents.kdl`. It does not set the global
  default, so ad-hoc panes keep the wrong shell. This is exactly the gap being closed.

## Sub-decisions

### A. Path form — full path (matches WezTerm) with a bare-`pwsh` fallback

Use the **full path** to mirror WezTerm exactly and avoid PATH ambiguity. The implementation verifies
the path exists (`Test-Path`) before committing it; if a machine has pwsh elsewhere, fall back to bare
`"pwsh"` (the `agents` layout already proves bare `pwsh` resolves on PATH here). KDL escaping: use
doubled backslashes (`C:\\Program Files\\...`); confirm Zellij parses it with `zellij setup --check`.

### B. The `-NoLogo` banner — accepted (A1)

Zellij's `default_shell` takes a path only and **cannot carry `-NoLogo`**, so each new pane prints
pwsh's startup banner. On modern pwsh (7.2+) that is a single version line, not the old copyright
block. **Decision: accept the banner** (option A1) — zero extra files, no wrapper process, and the
most-used flow (`agents` layout) already passes `-NoLogo`. The divergence from WezTerm is cosmetic only.

Rejected alternative **A2 (exact parity via shim):** a committed `pwsh-nologo.cmd` (`@"…\pwsh.exe"
-NoLogo %*`) pointed at by `default_shell`. Gives true no-banner on every pane, but costs an extra
committed file, a `cmd.exe` wrapper process per pane, and threads through the cwd bug below. Not worth
it for a one-line cosmetic banner. (Documented here so it's a known easy follow-on if the banner annoys.)

## Known issues to disclose / verify (not blockers)

- **CWD inheritance — [zellij#5052](https://github.com/zellij-org/zellij/issues/5052) (OPEN, no fix,
  no workaround):** with `default_shell` set to pwsh on Windows, a new ad-hoc pane may open in the
  session's **startup** directory rather than the directory you `cd`'d into. The implementation will
  **verify whether 0.44.3 still exhibits this** and test whether the existing prompt's OSC-7 cwd
  reporting (starship) mitigates it. The `agents` layout (explicit per-pane `cwd`) and session
  persistence are unaffected regardless. If present and unmitigated, it is documented as a known
  limitation — it does not block shipping the default-shell change.
- **Editing the live config — [zellij#4938](https://github.com/zellij-org/zellij/issues/4938):** on
  Windows Zellij defaults its config dir to `%APPDATA%\Zellij\config`, so naive edits to
  `~/.config/zellij` appear to do nothing. This machine already redirects via `ZELLIJ_CONFIG_DIR` →
  `~/.config/zellij` (shipped in Phase A). The implementation **confirms with `zellij setup --check`**
  that the active `[CONFIG FILE]` is the `~/.config/zellij/config.kdl` we edit, so we don't edit a dead file.

## Portability note

`.config/zellij` is **Windows-only in practice today** — neither `deploy.sh` nor `setup_mac.sh`
symlinks it (verified 2026-06-25). A Windows path in `default_shell` is therefore safe now. The intent
of the shared `~/.config/zellij` path is future cross-OS parity; if Zellij is later adopted on
macOS/Linux, `default_shell` must be guarded (those OSes want `$SHELL`/zsh, not a Windows pwsh path).
A comment in `config.kdl` records this so the trap is visible. Building OS-conditional machinery now
is out of scope (YAGNI) — Zellij KDL has no OS conditionals anyway.

## Scope / non-goals

- **In scope:** one line added to `.config/zellij/config.kdl` (`default_shell`), plus verification.
- **Out of scope:** the A2 shim; any `deploy_windows.ps1` change (the symlink + `ZELLIJ_CONFIG_DIR`
  from Phase A already route edits to the live config); macOS/Linux; WSL/tmux; the `agents` layout
  (it keeps its explicit `command "pwsh" args "-NoLogo"`).

## Acceptance criteria

- `zellij setup --check` shows the active `[CONFIG FILE]` at `~/.config/zellij/config.kdl` and reports
  **no KDL parse error** after the `default_shell` line is added.
- A plain `zellij` session's **initial pane**, an **ad-hoc `n`-spawned pane**, and a **new tab** all
  open **pwsh 7** (verify via `$PSVersionTable.PSVersion.Major` ≥ 7 and `$PSVersionTable.PSEdition`
  = `Core` in each).
- The cwd-bug behavior (#5052) on 0.44.3 is **recorded** (reproduces or not; mitigated by OSC-7 or not),
  so the limitation is known rather than surprising.
- WSL/tmux flow, the `agents` layout, and macOS/Linux behavior are unchanged.

## Open items (resolved during implementation)

- Confirm the pwsh 7 full path on this machine (`Test-Path`); choose full-path vs bare-`pwsh` fallback.
- Confirm `zellij#5052` reproduction status on 0.44.3 and whether the prompt's OSC-7 mitigates it.
