# WezTerm Preserve-CWD-on-Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make WezTerm pane splits (and new tabs) open in the active pane's current working directory instead of falling back to the home directory.

**Architecture:** A single shared helper, `pane_command(pane)`, builds the `SpawnCommand` used by both the split bindings and the new-tab binding. It sets `cwd` from `pane:get_current_working_dir().file_path` — the native path string `SpawnCommand.cwd` requires — fixing the current code that passes the `Url` object directly.

**Tech Stack:** WezTerm (`20260607` nightly) Lua config; PowerShell + `wezterm` CLI for verification. No test framework — this repo has no traditional build/test system (see `AGENTS.md`), so verification is a config-parse smoke check plus a scripted behavioral check via `wezterm cli list`.

## Global Constraints

- **Single file:** all edits are in `.config/wezterm/wezterm.lua` (absolute: `C:\Users\mint\dotfiles\.config\wezterm\wezterm.lua`). No other file changes.
- **Windows-only path:** all edited code lives inside the existing `if is_windows then` block. Do not touch macOS/Linux behavior.
- **Lua style (`.editorconfig`):** 4-space indent, ≤120 col lines, LF endings, final newline. Match surrounding indentation exactly.
- **Commit by explicit path ONLY:** the working tree has unrelated uncommitted Phase-C work (`.config/zellij/layouts/agents.kdl`, `claude/settings.json`, `.config/komorebi/komorebi.ahk`, untracked planning docs). NEVER `git add -A` / `git add .`. Stage only `.config/wezterm/wezterm.lua`.
- **No AI-attribution in commits:** no `Co-Authored-By` / "Generated with" trailers (user's global rule).
- **Branch:** stay on the current branch `feat/zellij-windows` (recent `feat(wezterm): …` commits already land here).

---

### Task 1: Introduce `pane_command` helper and fix pane splits

**Files:**
- Modify: `.config/wezterm/wezterm.lua:292-307` (the `split_current_pane` function — insert the helper immediately above it and simplify the function body).

**Interfaces:**
- Consumes: module-scoped `pwsh` (string, defined at `wezterm.lua:104`), `wezterm.action` aliased as `act`, `wezterm.action_callback`. All already in scope at this location.
- Produces: `local function pane_command(pane) -> table` — returns a `SpawnCommand` table `{ domain = "CurrentPaneDomain", args? = { pwsh, "-NoLogo" }, cwd? = <native path string> }`. Consumed by Task 2.

- [ ] **Step 1: Record the baseline (red state)**

In a WezTerm pane, `cd` into a non-home directory, e.g.:

```powershell
cd C:\Users\mint\dotfiles
```

Press `Ctrl+Space` then `v` (split right). Observe the **bug**: the new split opens in the home directory (`C:\Users\mint`), not `…\dotfiles`. Confirm objectively — the most recently created pane shows the wrong cwd:

```powershell
wezterm cli list --format json | ConvertFrom-Json | Select-Object pane_id, cwd | Sort-Object pane_id | Select-Object -Last 3
```

Expected (baseline/bug): the newest pane's `cwd` is `file:///C:/Users/mint` (home), not the source dir. Close the stray pane afterward (`Ctrl+Space` then `x`).

- [ ] **Step 2: Edit — add the helper and simplify `split_current_pane`**

Replace this exact block (`wezterm.lua:292-307`):

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
    -- Build a SpawnCommand for actions launched from the current pane: stay in the
    -- same domain, relaunch pwsh for local panes, and inherit the active pane's
    -- working directory. get_current_working_dir() returns a Url object
    -- (WezTerm 20240127+); SpawnCommand.cwd wants a string, so use .file_path.
    local function pane_command(pane)
        local command = { domain = "CurrentPaneDomain" }
        if pane:get_domain_name() == "local" then
            command.args = { pwsh, "-NoLogo" }
        end
        local cwd = pane:get_current_working_dir()
        if cwd then
            command.cwd = cwd.file_path
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

- [ ] **Step 3: Parse check — config still loads (no Lua error)**

Run:

```powershell
wezterm show-keys 2>&1 | Select-String -Pattern "leader_mode"; "exit=$LASTEXITCODE"
```

Expected: prints a line containing `Key Table: leader_mode` and `exit=0`. (A Lua error would make WezTerm fall back to the default config, so `leader_mode` would be absent.)

- [ ] **Step 4: Behavioral check — splits now inherit cwd (green state)**

WezTerm auto-reloads the config on save (`automatically_reload_config` defaults on; not disabled in this config). In a pane, `cd C:\Users\mint\dotfiles`, then press `Ctrl+Space` then `v`, and again `Ctrl+Space` then `s`. Both new panes' prompts should show `…\dotfiles`. Confirm objectively:

```powershell
wezterm cli list --format json | ConvertFrom-Json | Select-Object pane_id, cwd | Sort-Object pane_id | Select-Object -Last 3
```

Expected: the newly created panes' `cwd` is `file:///C:/Users/mint/dotfiles`. Close the test panes (`Ctrl+Space` then `x`) when done.

- [ ] **Step 5: Commit (explicit path only)**

```bash
git add .config/wezterm/wezterm.lua
git commit -m "fix(wezterm): preserve cwd on pane split via Url.file_path"
```

---

### Task 2: Route the new-tab binding through `pane_command`

**Files:**
- Modify: `.config/wezterm/wezterm.lua:407-416` (the `Leader t` entry in the `leader_mode` key table).

**Interfaces:**
- Consumes: `pane_command(pane)` from Task 1; `act.SpawnCommandInNewTab`, `wezterm.action_callback` (in scope).
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Edit — use the shared helper for the new-tab handler**

Replace this exact block (`wezterm.lua:407-416`):

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

- [ ] **Step 2: Parse check — config still loads**

Run:

```powershell
wezterm show-keys 2>&1 | Select-String -Pattern "leader_mode"; "exit=$LASTEXITCODE"
```

Expected: prints `Key Table: leader_mode` and `exit=0`.

- [ ] **Step 3: Behavioral check — new tab inherits cwd**

In a pane, `cd C:\Users\mint\dotfiles`, then press `Ctrl+Space` then `t` (new tab). The new tab's prompt should show `…\dotfiles`. Confirm objectively:

```powershell
wezterm cli list --format json | ConvertFrom-Json | Select-Object pane_id, tab_id, cwd | Sort-Object tab_id | Select-Object -Last 3
```

Expected: the new tab's pane has `cwd` = `file:///C:/Users/mint/dotfiles`. Close the test tab (`Ctrl+Space` then `&`) when done.

- [ ] **Step 4: Commit (explicit path only)**

```bash
git add .config/wezterm/wezterm.lua
git commit -m "refactor(wezterm): route new-tab through shared pane_command helper"
```

---

## Self-Review

**1. Spec coverage** — every section of `docs/superpowers/specs/2026-06-25-wezterm-preserve-cwd-on-split-design.md` maps to a task:
- Root-cause fix (`command.cwd = cwd.file_path`) → Task 1, Step 2.
- `pane_command` helper, placement above `split_current_pane`, `pwsh` in scope → Task 1, Step 2.
- `split_current_pane` simplification → Task 1, Step 2.
- `Leader t` routed through helper → Task 2, Step 1.
- "Why it is safe" (type-robust / non-file URL / WSL-Zellij unaffected) → properties of the code as written; no separate task needed (WSL/Zellij never reach this path per `wezterm.lua:275-277`).
- Verification plan (reload, cd, Leader v/s/t, `wezterm cli list`) → Task 1 Steps 3-4, Task 2 Steps 2-3.
- Out-of-scope items (macOS/Linux, smart-splits, OSC 7) → untouched; enforced by Global Constraints.

**2. Placeholder scan** — no TBD/TODO/"handle edge cases"/"similar to Task N". Every code step shows the full before/after block; every command step shows exact command and expected output.

**3. Type consistency** — `pane_command` is named identically in its definition (Task 1) and both call sites (Task 1 split, Task 2 tab). It returns a `SpawnCommand` table consumed by `act.SplitPane{ command = … }` and `act.SpawnCommandInNewTab(…)`, both of which accept a `SpawnCommand`. `cwd.file_path` is a string (or `nil`), matching `SpawnCommand.cwd`'s expected string type.
