# WezTerm Preserve-CWD-on-Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make WezTerm pane splits (and new tabs) open in the active pane's current working directory instead of falling back to the home directory.

**Architecture:** A single shared helper, `pane_command(pane)`, builds the `SpawnCommand` used by both the split bindings and the new-tab binding. It sets the domain (`CurrentPaneDomain`) and, for local panes, the program (`pwsh`), and **deliberately does not set `cwd`** — a `CurrentPaneDomain` spawn inherits the active pane's directory and WezTerm converts the pane's cwd URL to a native path correctly on its own.

> ⚠️ **Correction / dead-end to avoid (learned the hard way):** Do **not** try to set
> `command.cwd = pane:get_current_working_dir().file_path`. On Windows `file_path`
> returns a Unix-style `/C:/Users/…` string (leading slash), which Windows rejects
> with `os error 123` (`ERROR_INVALID_NAME`), so WezTerm silently falls back to the
> home directory — the exact bug we're fixing. The original `command.cwd = cwd`
> (passing the `Url` object) failed the same way. The fix is to **omit `cwd`**, not
> to compute it. See the design spec's "Root cause" + "Correction" sections.

**Tech Stack:** WezTerm (`20260607` nightly) Lua config; PowerShell + `wezterm` CLI for verification. No test framework — this repo has no traditional build/test system (see `AGENTS.md`), so verification is a config-parse smoke check, a CLI inheritance test, and a behavioral check after an explicit config reload.

## Global Constraints

- **Single file:** all edits are in `.config/wezterm/wezterm.lua` (absolute: `C:\Users\mint\dotfiles\.config\wezterm\wezterm.lua`). No other file changes.
- **Windows-only path:** all edited code lives inside the existing `if is_windows then` block. Do not touch macOS/Linux behavior.
- **Lua style (`.editorconfig`):** 4-space indent, ≤120 col lines, LF endings, final newline. Match surrounding indentation exactly.
- **Commit by explicit path ONLY:** the working tree carries unrelated concurrent Phase-C work. NEVER `git add -A` / `git add .`. Stage only `.config/wezterm/wezterm.lua`.
- **No AI-attribution in commits:** no `Co-Authored-By` / "Generated with" trailers (user's global rule).
- **Branch:** stay on the current branch `feat/zellij-windows`.

---

### Task 1: Introduce `pane_command` helper (no `cwd`) and use it for splits

**Files:**
- Modify: `.config/wezterm/wezterm.lua` — the `split_current_pane` function (insert the helper immediately above it and simplify the function body).

**Interfaces:**
- Consumes: module-scoped `pwsh` (string), `wezterm.action` aliased as `act`, `wezterm.action_callback`. All already in scope at this location.
- Produces: `local function pane_command(pane) -> table` — returns a `SpawnCommand` table `{ domain = "CurrentPaneDomain", args? = { pwsh, "-NoLogo" } }` (no `cwd`). Consumed by Task 2.

- [ ] **Step 1: Edit — add the helper and simplify `split_current_pane`**

Replace the original `split_current_pane` block:

```lua
    local function split_current_pane(direction)
        return wezterm.action_callback(function(window, pane)
            local command = { domain = "CurrentPaneDomain" }

            if pane:get_domain_name() == "local" then
                command.args = { pwsh, "-NoLogo" }
            end

            local cwd = pane:get_current_working_dir()
            if cwd then
                command.cwd = cwd
            end

            window:perform_action(act.SplitPane({ direction = direction, command = command }), pane)
        end)
    end
```

with:

```lua
    -- Build a SpawnCommand for actions launched from the current pane: keep the
    -- same domain and relaunch pwsh for local panes. Deliberately do NOT set `cwd`:
    -- a CurrentPaneDomain command already inherits the active pane's working
    -- directory, and WezTerm converts that URL to a native path correctly. Setting
    -- cwd ourselves from get_current_working_dir().file_path breaks on Windows --
    -- it returns a "/C:/..." path WezTerm rejects (os error 123), silently falling
    -- back to the home directory.
    local function pane_command(pane)
        local command = { domain = "CurrentPaneDomain" }
        if pane:get_domain_name() == "local" then
            command.args = { pwsh, "-NoLogo" }
        end
        return command
    end

    local function split_current_pane(direction)
        return wezterm.action_callback(function(window, pane)
            window:perform_action(
                act.SplitPane({ direction = direction, command = pane_command(pane) }),
                pane
            )
        end)
    end
```

- [ ] **Step 2: Parse check — config still loads (no Lua error)**

Run:

```powershell
wezterm show-keys 2>&1 | Select-String -Pattern "leader_mode"; "exit=$LASTEXITCODE"
```

Expected: a line containing `Key Table: leader_mode` and `exit=0`. (A Lua error makes WezTerm fall back to the default config, so `leader_mode` would be absent.)

- [ ] **Step 3: Mechanism check — confirm inheritance works via CLI (no GUI needed)**

Find a pwsh pane sitting in a non-home directory, split it **without** `--cwd`, and confirm the new pane inherits that directory:

```powershell
# pick a pwsh pane id in a known dir from: wezterm cli list --format json
$new = (wezterm cli split-pane --pane-id <ID> --percent 20 -- pwsh -NoLogo 2>&1).Trim()
wezterm cli list --format json | ConvertFrom-Json | Where-Object { $_.pane_id -eq [int]$new } | Select-Object pane_id, cwd
wezterm cli kill-pane --pane-id $new
```

Expected: the new pane's `cwd` equals the source pane's directory (not home).

- [ ] **Step 4: Behavioral check — splits inherit cwd (real keybinding)**

> ⚠️ **Force a reload first — do not trust auto-reload.** WezTerm's passive
> file-watcher is unreliable through the dir-symlink on Windows, so a saved edit
> may not be live. Press **`Ctrl+Shift+R`** in the target window before testing.

In a pwsh pane: `cd C:\Users\mint\dotfiles`, then `Ctrl+Space` then `v`, then `Ctrl+Space` then `s`. Confirm objectively:

```powershell
wezterm cli list --format json | ConvertFrom-Json | Select-Object pane_id, cwd | Sort-Object pane_id | Select-Object -Last 3
```

Expected: the new panes' `cwd` is `file:///C:/Users/mint/dotfiles`.
Optional cross-check via logs: no `os error 123` / `not readable` lines appear in `~/.local/share/wezterm/wezterm-gui*.txt` after the test. (A temporary `wezterm.log_warn` inside `pane_command` is a reliable way to prove the *fixed* config actually ran — remove it before committing.)

- [ ] **Step 5: Commit (explicit path only)**

```bash
git add .config/wezterm/wezterm.lua
git commit -m "fix(wezterm): inherit cwd on pane split (omit SpawnCommand.cwd)"
```

---

### Task 2: Route the new-tab binding through `pane_command`

**Files:**
- Modify: `.config/wezterm/wezterm.lua` — the `Leader t` entry in the `leader_mode` key table.

**Interfaces:**
- Consumes: `pane_command(pane)` from Task 1; `act.SpawnCommandInNewTab`, `wezterm.action_callback` (in scope).
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Edit — use the shared helper for the new-tab handler**

Replace the original `Leader t` block:

```lua
            {
                key = "t",
                action = wezterm.action_callback(function(window, pane)
                    local command = { domain = "CurrentPaneDomain" }
                    if pane:get_domain_name() == "local" then
                        command.args = { pwsh, "-NoLogo" }
                    end
                    window:perform_action(act.SpawnCommandInNewTab(command), pane)
                end),
            },
```

with:

```lua
            {
                key = "t",
                action = wezterm.action_callback(function(window, pane)
                    window:perform_action(act.SpawnCommandInNewTab(pane_command(pane)), pane)
                end),
            },
```

(The original already omitted `cwd`, so this is a DRY/consistency change, not a behavior change for tabs.)

- [ ] **Step 2: Parse check — config still loads**

```powershell
wezterm show-keys 2>&1 | Select-String -Pattern "leader_mode"; "exit=$LASTEXITCODE"
```

Expected: `Key Table: leader_mode` and `exit=0`.

- [ ] **Step 3: Behavioral check — new tab inherits cwd**

Force-reload (`Ctrl+Shift+R`), `cd C:\Users\mint\dotfiles`, then `Ctrl+Space` then `t`. Confirm:

```powershell
wezterm cli list --format json | ConvertFrom-Json | Select-Object pane_id, tab_id, cwd | Sort-Object tab_id | Select-Object -Last 3
```

Expected: the new tab's pane has `cwd` = `file:///C:/Users/mint/dotfiles`.

- [ ] **Step 4: Commit (explicit path only)**

```bash
git add .config/wezterm/wezterm.lua
git commit -m "refactor(wezterm): route new-tab through shared pane_command helper"
```

---

## Self-Review

**1. Spec coverage** — every section of `docs/superpowers/specs/2026-06-25-wezterm-preserve-cwd-on-split-design.md` maps to a task:
- Fix (omit `cwd`, inherit) → Task 1, Step 1.
- `pane_command` helper, placement above `split_current_pane`, `pwsh` in scope → Task 1, Step 1.
- `split_current_pane` simplification → Task 1, Step 1.
- `Leader t` routed through helper → Task 2, Step 1.
- "Why it is safe" (uses WezTerm's own inheritance; WSL/Zellij never reach this path per `wezterm.lua:275-277`) → properties of the code as written.
- Verification (CLI inheritance proof, forced-reload behavioral check, `wezterm cli list`, parse smoke check) → Task 1 Steps 2-4, Task 2 Steps 2-3.
- Out-of-scope items (macOS/Linux, smart-splits, OSC 7) → untouched; enforced by Global Constraints.

**2. Placeholder scan** — `<ID>` in Task 1 Step 3 is an intentional runtime value (the operator picks a live pane id from `wezterm cli list`), not an unfilled placeholder. Every code/edit step shows full before/after blocks; every command step shows exact command and expected output.

**3. Type consistency** — `pane_command` is named identically in its definition (Task 1) and both call sites (Task 1 split, Task 2 tab). It returns a `SpawnCommand` table consumed by `act.SplitPane{ command = … }` and `act.SpawnCommandInNewTab(…)`, both of which accept a `SpawnCommand`. No `cwd` field is set, so there is no string/Url type hazard.
