# Zellij Windows default shell = PowerShell 7 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every new Zellij pane/tab on Windows open PowerShell 7 (`pwsh`) by default, matching the WezTerm setup, by adding a single `default_shell` line to the shared Zellij config.

**Architecture:** Zellij's `default_shell` option (the canonical mechanism, covering the initial pane, ad-hoc split panes, and new tabs in one declaration) is set to the full path of pwsh 7 in `.config/zellij/config.kdl`. That repo file is symlinked to `~/.config/zellij/config.kdl` and reached by Zellij via the `ZELLIJ_CONFIG_DIR` env var shipped in Phase A, so editing the repo file edits the live config. The `agents` layout's explicit `command "pwsh"` is unaffected. A known upstream cwd bug (zellij#5052) is verified and documented rather than worked around.

**Tech Stack:** Zellij 0.44.3 (Rust/ConPTY, via scoop shim on PATH), KDL config, PowerShell 7 (`pwsh`), WezTerm Lua (read-only reference).

**Design spec:** `docs/superpowers/specs/2026-06-25-zellij-windows-default-shell-pwsh-design.md`

## Global Constraints

- **Windows-only change.** Touch only `.config/zellij/config.kdl`. Do **not** modify `deploy_windows.ps1`, `deploy.sh`, `setup_mac.sh`, `wezterm.lua`, tmux configs, or the macOS/Linux branches of anything. The Phase A symlink + `ZELLIJ_CONFIG_DIR` already route edits to the live config — no deploy change is needed.
- **Do NOT touch `.config/zellij/layouts/agents.kdl`.** It has concurrent staged changes from another session and is out of scope. It keeps its explicit `command "pwsh" args "-NoLogo"`.
- **Edit the live config.** On Windows Zellij defaults its config dir to `%APPDATA%\Zellij\config` (zellij#4938); this machine redirects via `ZELLIJ_CONFIG_DIR` → `~/.config/zellij`. Confirm with `zellij setup --check` that the active `[CONFIG FILE]` is `~/.config/zellij/config.kdl` before and after editing, so no dead file is edited.
- **Parity target (from `wezterm.lua:99-104,219`):** pwsh 7, full path — primary `C:\Program Files\PowerShell\7\pwsh.exe`, fallback `C:\Program Files\PowerShell\pwsh.exe`. Bare `"pwsh"` (PATH) is the last-resort fallback if neither path exists.
- **`default_shell` takes a PATH ONLY** — it cannot pass `-NoLogo`. The 1-line pwsh banner per pane is accepted (decision A1); no shim. Do not attempt to append arguments to `default_shell`.
- **KDL escaping is a footgun.** Use doubled backslashes (`"C:\\Program Files\\..."`) or a KDL raw string (`r"C:\Program Files\..."`). Always confirm with `zellij setup --check` (no parse error) before relying on it.
- **Verification is functional, not unit-test-based** (this is dotfiles/infra). Each task ends by running a command and observing a concrete result, then committing.
- **Branch:** work on `feat/zellij-windows` (already checked out). The branch currently has concurrent Phase C activity and an uncommitted/staged `agents.kdl` change that is **not** part of this work — before committing, confirm the branch is settled and stage **only** `.config/zellij/config.kdl` by explicit path (never `git add -A`).

---

## Task 1: Set `default_shell` to pwsh 7 and verify it launches everywhere

**Files:**
- Modify: `C:\Users\mint\dotfiles\.config\zellij\config.kdl` (add one option, after the `scrollback_editor "nvim"` line)

**Interfaces:**
- Consumes: the live config resolved via `ZELLIJ_CONFIG_DIR` (Phase A); the WezTerm pwsh path candidates (reference only).
- Produces: a `default_shell` declaration that every non-layout pane inherits.

- [ ] **Step 1: Confirm we will edit the live config file (#4938 guard)**

Run (PowerShell):
```powershell
zellij setup --check
```
Expected: a `[CONFIG DIR] ...` line pointing at `C:\Users\mint\.config\zellij`, a `[CONFIG FILE] ...` line **found** at `C:\Users\mint\.config\zellij\config.kdl`, and **no KDL parse errors**. If `[CONFIG FILE]` is `%APPDATA%\Zellij\config` instead, STOP — `ZELLIJ_CONFIG_DIR` isn't set in this shell; open a fresh shell (Phase A persisted it) and re-check.

- [ ] **Step 2: Resolve the pwsh 7 full path (mirror WezTerm's detection)**

Run:
```powershell
$candidates = @(
    "C:\Program Files\PowerShell\7\pwsh.exe",
    "C:\Program Files\PowerShell\pwsh.exe"
)
$pwsh = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $pwsh) { "NONE FOUND — fall back to bare 'pwsh'"; $pwsh = "pwsh" }
"resolved: $pwsh"
& $pwsh -NoLogo -Command '$PSVersionTable.PSVersion.ToString() + "  " + $PSVersionTable.PSEdition'
```
Expected: `resolved: C:\Program Files\PowerShell\7\pwsh.exe` (primary), and a version line like `7.4.x  Core`. **Record which path resolved** — that exact string goes into the config in Step 3. If the output is `NONE FOUND`, use the bare `"pwsh"` form in Step 3 instead of a full path.

- [ ] **Step 3: Add the `default_shell` line to `config.kdl`**

In `C:\Users\mint\dotfiles\.config\zellij\config.kdl`, insert the following block immediately after the `scrollback_editor "nvim"` line (use the path resolved in Step 2; the primary full path is shown):
```kdl

// Default shell for new panes/tabs — match the WezTerm setup (pwsh 7; see wezterm.lua:99-104,219).
// Windows-only today: this dir is NOT symlinked on macOS/Linux (deploy.sh / setup_mac.sh skip zellij),
// so a Windows path is safe here. If zellij is later adopted on mac/linux, guard this — those OSes
// want $SHELL/zsh, not a Windows pwsh path.
// NOTE: default_shell takes a PATH ONLY — it can't pass -NoLogo, so pwsh prints its 1-line startup
// banner per pane (cosmetic; pwsh 7.2+ trimmed it to a single line). The `agents` layout still passes
// -NoLogo. KNOWN BUG zellij#5052: ad-hoc panes may open in the startup dir, not the cd'd dir (Task 2).
default_shell "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
```
If Step 2 reported `NONE FOUND`, use `default_shell "pwsh"` for the last line instead. (If you prefer to avoid backslash escaping, the equivalent raw-string form is `default_shell r"C:\Program Files\PowerShell\7\pwsh.exe"`.)

- [ ] **Step 4: Verify Zellij parses the edited config (no KDL error)**

Run:
```powershell
zellij setup --check
```
Expected: `[CONFIG FILE]` still found at `~/.config/zellij/config.kdl`, and **no parse error**. If a parse/escaping error appears, switch the value to the raw-string form (`r"C:\Program Files\PowerShell\7\pwsh.exe"`) and re-run until clean.

- [ ] **Step 5: Verify the INITIAL pane opens pwsh 7**

Run:
```powershell
zellij -s shell-test
```
In the initial pane, run:
```powershell
$PSVersionTable.PSVersion.Major; $PSVersionTable.PSEdition
```
Expected: `7` then `Core`. (Leave the session running for Step 6.)

- [ ] **Step 6: Verify an AD-HOC split pane and a NEW TAB also open pwsh 7**

Still inside the `shell-test` session:
1. Open a split pane: press `Ctrl+Space` (enter TMUX mode), then `"` (split down). In the new pane run `$PSVersionTable.PSVersion.Major; $PSVersionTable.PSEdition` → expect `7` / `Core`.
2. Open a new tab: press `Ctrl+Space`, then `c`. In the new tab's pane run the same two commands → expect `7` / `Core`.

Then tear down the test session:
```powershell
zellij kill-session shell-test
```
Expected: all three pane types (initial, split, new tab) reported `7` / `Core`. (If `Ctrl+Space` doesn't enter TMUX mode, use the `Ctrl b` fallback noted in `config.kdl`.)

- [ ] **Step 7: Confirm the `agents` layout is untouched and still works**

Run:
```powershell
zellij -s agents-test --layout agents
```
Expected: the `agents` tab opens three pwsh panes (unchanged behavior). Tear down: `zellij kill-session agents-test`. This confirms the global `default_shell` did not disturb the layout's explicit `command "pwsh"`.

- [ ] **Step 8: Commit (only the config file, by explicit path)**

First confirm the branch is settled (no other session mid-commit) and that only the intended file is staged:
```bash
git add .config/zellij/config.kdl
git status --short
```
Expected: exactly `M  .config/zellij/config.kdl` staged (plus any unrelated unstaged entries left alone — do NOT stage `agents.kdl` or `settings.json`). Then:
```bash
git commit -m "feat(zellij): default_shell = pwsh 7 on Windows (parity with WezTerm)"
```

---

## Task 2: Verify and document the #5052 cwd behavior on 0.44.3

**Files:**
- Modify (only if the bug reproduces and is not mitigated): `C:\Users\mint\dotfiles\.config\zellij\config.kdl` (tighten the existing `// KNOWN BUG zellij#5052 ...` comment with the observed result)

**Interfaces:**
- Consumes: the `default_shell` from Task 1.
- Produces: a recorded, accurate statement of whether new panes inherit the current working directory on this Zellij version — so the limitation is known, not surprising.

- [ ] **Step 1: Reproduce the cwd test**

Run:
```powershell
cd C:\Users\mint\dotfiles
zellij -s cwd-test
```
In the initial pane:
```powershell
cd .\.config\zellij
Get-Location
```
Then open a split pane (`Ctrl+Space`, then `"`), and in the **new** pane run:
```powershell
Get-Location
```
Expected — one of:
- **Bug present (#5052):** new pane is at `C:\Users\mint\dotfiles` (the session startup dir).
- **Bug absent/fixed on 0.44.3:** new pane is at `C:\Users\mint\dotfiles\.config\zellij` (the cd'd dir).

**Record which occurred.** Leave the session open for Step 2.

- [ ] **Step 2: Test whether the prompt's OSC-7 reporting mitigates it**

Only relevant if Step 1 showed the bug. In the cd'd initial pane, let the prompt fully render (starship), then check whether the shell emits an OSC-7 cwd sequence:
```powershell
"OSC7 in prompt? -> " + ([bool]($env:STARSHIP_CONFIG -ne $null -or (Get-Command starship -ErrorAction SilentlyContinue)))
```
Then split again and re-check `Get-Location` in the new pane. Expected: determine empirically whether a fully-rendered OSC-7-emitting prompt causes the split pane to inherit the cd'd dir. **Record the result.** Tear down:
```powershell
zellij kill-session cwd-test
```

- [ ] **Step 3: Update the config comment to match reality**

Edit the `// KNOWN BUG zellij#5052 ...` line added in Task 1 to state the observed outcome precisely. Use one of:
- Bug absent: `// zellij#5052 (ad-hoc panes opening in the startup dir) does NOT reproduce on 0.44.3 — verified <date>.`
- Bug present, unmitigated: `// KNOWN LIMITATION zellij#5052: ad-hoc panes open in the session startup dir, not the cd'd dir (0.44.3, verified <date>). Use the agents layout's explicit cwd, or 'cd' in the new pane.`
- Bug present, OSC-7 mitigates: `// zellij#5052: ad-hoc panes inherit cwd only once the starship/OSC-7 prompt has rendered (0.44.3, verified <date>).`

(If the bug is absent, this is the only change in Task 2 and it is trivial — still commit it so the record is in git.)

- [ ] **Step 4: Commit the documented finding**

```bash
git add .config/zellij/config.kdl
git commit -m "docs(zellij): record #5052 cwd behavior on 0.44.3"
```

- [ ] **Step 5: Note for session capture**

The #5052 finding (reproduces or not, OSC-7 mitigation or not, on 0.44.3) is durable knowledge for the `05.Wiki` `Zellij` entity. Surface it at `/close` so it's captured alongside the existing Zellij notes — do not write the wiki inline here.

---

## Self-Review (completed by plan author)

**Spec coverage:**
- Decision (`default_shell` = pwsh 7 full path in `config.kdl`) → Task 1 Steps 2–3 ✓.
- Sub-decision A (full path + bare fallback, escaping footgun) → Task 1 Steps 2, 3, 4 (raw-string fallback) ✓.
- Sub-decision B (accept banner, A1; no shim) → encoded in the config comment + Global Constraints; no shim task exists ✓.
- Acceptance: live-config guard (#4938) → T1 S1; pwsh in initial/split/new-tab → T1 S5–S6; agents/WSL unchanged → T1 S7 + constraints; #5052 recorded → Task 2 ✓.
- Portability note → captured verbatim in the config comment (T1 S3) ✓.

**Placeholder scan:** No TBD/TODO. The two spec "open items" are resolved by concrete measure-then-decide steps with explicit fallbacks (T1 S2 path resolution, T2 S1–S2 cwd verification), not vague instructions.

**Type/identifier consistency:** session names (`shell-test`, `agents-test`, `cwd-test`) each created and killed within their task; the `default_shell` value string is identical in spec and T1 S3; the `zellij#5052` reference and the config comment text match between T1 S3 and T2 S3; `Ctrl+Space`→`"`/`c` bindings match the `config.kdl` tmux-mode prefix.

**Carried risks:** `Ctrl+Space` Kitty-protocol dependence (fallback `Ctrl b`, noted T1 S6); concurrent-branch git state (explicit-path staging + settle check, T1 S8).
