# Continuity — dotfiles
_Updated: 2026-07-01 03:30 +07 · session 270f69a8_

## Changes this session
- **No code/config changes** — this session was investigation only (SSH access to WezTerm's persistent Windows mux). Nothing committed to the dotfiles repo.
- **Verified live, against the `win` host (192.168.50.25, user `mint`):**
  - OpenSSH server is already running and reachable — `ssh win echo ok` returns cleanly. No setup needed (corrects my own assumption from earlier in the session).
  - `wezterm.exe` and `wezterm-mux-server.exe` both resolve on PATH for a **non-interactive** SSH session (`C:\Program Files\WezTerm\` — direct installer, not scoop). No `remote_wezterm_path` override needed in any future `wezterm.lua` config.
  - Local (Mac) WezTerm version: `20240203-110809-5046fc22` — confirmed via `wezterm --version`.
- **Wiki captured** (vault commit `a7f1c44`): created [[WezTerm SSH Domains for Remote Mux Access]]; updated [[WezTerm Multiplexer Persistence on Windows]] (currency-correction callout) and [[PowerShell Automation Gotchas]] (new section on non-interactive-SSH profile noise + `where`/`where.exe`/BatchMode pitfalls).

## Decisions made
- **Zero `wezterm.lua` changes for SSHMUX access** — WezTerm auto-populates SSH domains from `~/.ssh/config` since `20230408-112425-69ae8472` (well below the installed version), and `Host win` already exists there. Hand-writing an explicit `config.ssh_domains` entry would just duplicate that alias. Connect with `wezterm connect SSHMUX:win`.
- **Did not wire `win` into the Leader+g remote picker** — out of scope for this session's ask (just reaching the mux), and Leader+g isn't even keybound on mac today (Windows-only in current `wezterm.lua`). Offered, not done.
- **Did not fix the PowerShell profile noise** (PSFzf/zoxide errors under non-interactive SSH) — flagged per Ponytail convention (notice, don't silently fix), left for Max to decide.

## Decisions pending / open
- **⚠ Primary blocker for tomorrow: WezTerm client/server version mismatch, unconfirmed.** Mac is on `20240203-110809-5046fc22`, the **last stable** release (Feb 2024) — NOT nightly. The existing wiki page on WezTerm mux persistence already states Windows is tracked on nightly (`update-everything.ps1`) and that the whole persistence/reattach story "effectively requires nightly." A stable↔nightly mux-protocol gap is the leading suspect if `wezterm connect SSHMUX:win` fails or misbehaves — **this is what Max meant by "our wezterm version is mismatched."**
- **`wezterm connect SSHMUX:win` itself has not been run yet** — it's a GUI action I can't drive or observe from here. Untested whether it actually attaches to the same persistent panes as the local GUI auto-attach (`default_gui_startup_args`), vs. spawning a separate daemon.
- **PowerShell profile gotcha left unfixed**: `Import-Module PSFzf` ("untrusted mount point" on the scoop module symlink) and the zoxide `Invoke-Expression` (empty string) both fire on every non-interactive SSH exec against `win`. Non-fatal (errors go to stderr, not stdout) but adds latency/noise to anything scripted against that host. Candidate fix: guard both behind `[Console]::IsOutputRedirected`.

## Next steps
1. **Check the Windows-side WezTerm version** (`wezterm --version` on `win`) and compare against the Mac's `20240203-110809-5046fc22`. If Windows is on nightly as expected, decide whether to bump the Mac to nightly to match (recommended, since the existing wiki page already concluded the persistence story needs it).
2. **Run `wezterm connect SSHMUX:win` from the Mac** and confirm the existing persistent tabs/panes show up (not a fresh session). That's the actual proof the SSH-domain wiring works.
3. If it fails, the version mismatch from step 1 is the first thing to rule out before debugging further.
4. Optional, only if wanted: wire `SSHMUX:win` into the Leader+g remote picker (`wezterm_remotes.lua` would need a new SSHMUX-domain spawn kind; a Leader+g keybind would also need adding on mac, since it's Windows-only today).
5. Optional, only if wanted: fix the two PowerShell profile errors under non-interactive SSH (see [[PowerShell Automation Gotchas]] for the exact guard).
