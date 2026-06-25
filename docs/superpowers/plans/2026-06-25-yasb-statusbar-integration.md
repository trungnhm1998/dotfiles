# YASB Status Bar (minimal) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace komorebi's built-in egui bar with a minimal YASB (Qt) bar showing komorebi workspaces + a clock, managed by the dotfiles.

**Architecture:** YASB runs as a standalone Qt process reading `~/.config/yasb/{config.yaml,styles.css}` (symlinked from the dotfiles). komorebi stops drawing its own bar (`bar_configurations: []`) and reserves the top strip via `global_work_area_offset` so tiled windows clear the YASB bar. `deploy_windows.ps1` installs YASB (winget) and creates the symlink.

**Tech Stack:** YASB (Python/Qt, winget `AmN.yasb`), komorebi (`komorebic`), PowerShell deploy script, YAML + CSS config.

**Design spec:** `docs/superpowers/specs/2026-06-25-yasb-statusbar-integration-design.md`

## Global Constraints

- **Platform:** Windows only. All runtime/verify steps assume PowerShell 7+ on the user's machine.
- **Branch:** Work continues on `feat/zellij-windows` (current). This branch has **concurrent work from another session** — every commit MUST use **explicit pathspecs**, never `git add -A` / `git add .`.
- **Commit hygiene:** **No `Co-Authored-By` trailers and no AI-attribution footers** (user's global git rule). Conventional-commit style messages (`feat(yasb): …`).
- **Theme:** Catppuccin **Frappe** — base `#303446`, text `#c6d0f5`, accent blue `#8caaee`, dim `#838ba7`. **Font:** `JetBrainsMono Nerd Font`. Icons use Nerd Font glyphs, never emoji.
- **komorebi commands** in YASB config use **plain `komorebic`** (no `--whkd`) — this setup drives komorebi via AutoHotkey, not whkd.
- **Symlinks** are created only with `New-Item -ItemType SymbolicLink` (needs an **elevated** shell or Developer Mode) — never git-bash `ln -s` (silently copies on Windows).
- **Liveness:** the config symlink targets the working tree, so to stay live across branch switches this work must eventually land on **`master`**.
- **Bar name contract:** the bar is named `yasb-bar` in `config.yaml`; `styles.css` targets it as `.yasb-bar`. Keep these in sync.

---

### Task 1: Create the YASB config (workspaces + clock, Frappe theme)

**Files:**
- Create: `.config/yasb/config.yaml`
- Create: `.config/yasb/styles.css`
- Create: `.config/yasb/README.md`

**Interfaces:**
- Produces: a bar named `yasb-bar` with widgets `workspaces` (`komorebi.workspaces.WorkspaceWidget`) and `clock` (`yasb.clock.ClockWidget`). Task 2's `global_work_area_offset.top` must match this bar's height (default 36 → reserve 40). Task 4 symlinks this directory to `~/.config/yasb`.

- [ ] **Step 1: Write `.config/yasb/config.yaml`**

```yaml
# YASB — minimal status bar (replaces komorebi-bar).
# Widgets: komorebi workspaces (left) + clock (center). Theming in styles.css.
# Docs: https://github.com/amnweb/yasb/wiki/Configuration
watch_stylesheet: true
watch_config: true
debug: false

# Tray-menu komorebi commands. This setup drives komorebi hotkeys via AutoHotkey
# (.config/komorebi/komorebi.ahk), NOT whkd — so no --whkd here.
komorebi:
  start_command: "komorebic start"
  stop_command: "komorebic stop"
  reload_command: "komorebic reload-configuration"

bars:
  yasb-bar:
    enabled: true
    screens: ['*']            # one bar on every monitor
    widgets:
      left: ["workspaces"]
      center: ["clock"]
      right: []

widgets:
  workspaces:
    type: "komorebi.workspaces.WorkspaceWidget"
    options:
      label_offline: "komorebi offline"
      label_workspace_btn: "{name}"
      label_workspace_active_btn: "{name}"
      label_workspace_populated_btn: "{name}"
      hide_empty_workspaces: true

  clock:
    type: "yasb.clock.ClockWidget"
    options:
      label: "{%H:%M}"
      label_alt: "{%a %d %b %H:%M:%S}"
      timezones: []
```

- [ ] **Step 2: Write `.config/yasb/styles.css`**

```css
/* YASB — minimal Catppuccin Frappe theme. Font: JetBrainsMono Nerd Font.
   Frappe: base #303446, text #c6d0f5, blue #8caaee, overlay1 #838ba7. */
* {
    font-family: 'JetBrainsMono Nerd Font';
    font-size: 13px;
    color: #c6d0f5;
}

.yasb-bar {
    background-color: #303446;
}

/* komorebi workspace buttons */
.ws-btn {
    background-color: transparent;
    color: #838ba7;          /* dim — inactive/empty */
    border: none;
    padding: 0 8px;
    margin: 0 1px;
}
.ws-btn.populated {
    color: #c6d0f5;          /* text — occupied */
}
.ws-btn.active {
    color: #303446;          /* base on accent */
    background-color: #8caaee;
    border-radius: 4px;
}
```

- [ ] **Step 3: Write `.config/yasb/README.md`**

```markdown
# YASB — Windows status bar

Replaces komorebi-bar (egui) with [YASB](https://github.com/amnweb/yasb) (Qt).
Minimal v1: komorebi workspaces + clock.

- **Config:** `config.yaml` (bar + widgets), `styles.css` (Catppuccin Frappe).
- **Deployed by:** `deploy_windows.ps1` symlinks this dir to `~/.config/yasb`.
- **Autostart (one-time):** `yasbc enable-autostart` (disable: `yasbc disable-autostart`).
- **Launch now:** `yasb`  ·  **List monitors:** `yasbc monitor-information`.

## Work-area reservation
komorebi reserves the top strip via `global_work_area_offset` in
`../komorebi/komorebi.json` — komorebi-bar's own offset is inert once
`bar_configurations` is empty. Tune `top` to the rendered bar height.

## Rollback to komorebi-bar
In `../komorebi/komorebi.json`: restore
`"bar_configurations": ["$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor1.json", "$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor2.json"]`,
remove `global_work_area_offset`, then `yasbc disable-autostart` and restart komorebi.
```

- [ ] **Step 4: Validate the YAML parses**

Run (Python with PyYAML, if available):
```bash
python -c "import yaml; yaml.safe_load(open(r'C:\Users\mint\dotfiles\.config\yasb\config.yaml')); print('YAML OK')"
```
Expected: `YAML OK`.
If Python/PyYAML is not installed, skip — YASB itself validates the file on load in Task 5 (with `debug: true` surfacing parse errors in its log). Do **not** block on this step.

- [ ] **Step 5: Commit**

```bash
git add .config/yasb/config.yaml .config/yasb/styles.css .config/yasb/README.md
git commit -m "feat(yasb): minimal config — komorebi workspaces + clock, Frappe theme"
```

---

### Task 2: Disable komorebi-bar and reserve the top strip

**Files:**
- Modify: `.config/komorebi/komorebi.json:26-29` (the `bar_configurations` array)

**Interfaces:**
- Consumes: the YASB bar height from Task 1 (default 36) → reserve `top: 40`.
- Produces: `global_work_area_offset` reserving the top strip; the three `komorebi.bar*.json` files become inert (retained for rollback, not deleted).

- [ ] **Step 1: Edit `komorebi.json` — empty the bar list, add the offset**

Replace this exact block (currently at `:26-29`):
```json
  "bar_configurations": [
    "$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor1.json",
    "$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor2.json"
  ],
```
with:
```json
  "bar_configurations": [],
  "global_work_area_offset": { "left": 0, "top": 40, "right": 0, "bottom": 0 },
```

- [ ] **Step 2: Validate the komorebi config**

Run:
```powershell
komorebic check
```
Expected: no schema/parse errors (exit 0). It may print warnings about unmanaged apps — those are unrelated and fine. If it reports `global_work_area_offset` as unknown (older komorebi build), fall back to applying it at runtime in Task 5 via `komorebic global-work-area-offset 0 40 0 0` and leave the JSON key out.

- [ ] **Step 3: Commit**

```bash
git add .config/komorebi/komorebi.json
git commit -m "feat(komorebi): disable built-in bar, reserve top strip for YASB"
```

---

### Task 3: Wire YASB into the Windows deploy script

**Files:**
- Modify: `deploy_windows.ps1:58` (winget package list — Windows-Specific Tools)
- Modify: `deploy_windows.ps1:77` (the `$symlinks` array — Directory symlinks)
- Modify: `deploy_windows.ps1:753-754` (post-install "Next steps" text)

**Interfaces:**
- Consumes: the `$symlinks` entry shape `@{ Source; Target; IsDirectory; Description }` and the package shape `@{ Id; Name }` already used in the file.
- Produces: a winget install of `AmN.yasb` and a symlink `~/.config/yasb` → `.config/yasb`, both handled by the existing generic loops (no new code paths).

- [ ] **Step 1: Add the winget package**

After the wezterm line (`:58`):
```powershell
    @{ Id = "wez.wezterm"; Name = "Wezterm" }
```
insert:
```powershell
    @{ Id = "AmN.yasb"; Name = "YASB" }
```
(Still inside the `# Windows-Specific Tools` group, before the `# Fonts` comment.)

- [ ] **Step 2: Add the directory symlink**

After the komorebi symlink block (ends at `:77`):
```powershell
    @{
        Source      = "$dotfilesRoot\.config\komorebi"
        Target      = "$HOME\.config\komorebi"
        IsDirectory = $true
        Description = "Komorebi tiling window manager"
    }
```
insert:
```powershell
    @{
        Source      = "$dotfilesRoot\.config\yasb"
        Target      = "$HOME\.config\yasb"
        IsDirectory = $true
        Description = "YASB status bar (Windows)"
    }
```

- [ ] **Step 3: Add a YASB line to the post-install "Next steps"**

After the Wezterm step (`:753-754`):
```powershell
  5. Wezterm should automatically pick up config from
     $HOME\.config\wezterm
```
insert:
```powershell

  6. Start the YASB status bar (replaces komorebi-bar)
     > yasb
     Enable launch-at-login (one-time): > yasbc enable-autostart
```

- [ ] **Step 4: Syntax-check the script**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("C:\Users\mint\dotfiles\deploy_windows.ps1", [ref]$null, [ref]$null); Write-Output "PARSE OK"
```
Expected: `PARSE OK` with no parser exceptions.

- [ ] **Step 5: Dry-run to confirm the new symlink + package appear**

Run:
```powershell
C:\Users\mint\dotfiles\deploy_windows.ps1 -DryRun
```
Expected output contains:
- a line for the YASB package (in the winget section), and
- `[DRY RUN] Would create symlink: C:\Users\mint\.config\yasb -> C:\Users\mint\dotfiles\.config\yasb`.

- [ ] **Step 6: Commit**

```bash
git add deploy_windows.ps1
git commit -m "feat(deploy): install + symlink YASB on Windows"
```

---

### Task 4: Provision YASB on the live machine (install + symlink)

> **Admin/live step.** Symlink creation needs an **elevated** PowerShell (or Developer Mode). If the agent's shell is not elevated, hand these commands to the user (e.g. run via `! <command>` or an admin PowerShell). No repo commit in this task — it changes system state only.

**Files:** none (system state).

- [ ] **Step 1: Install YASB**

Run:
```powershell
winget install --exact --id AmN.yasb
```
Expected: install succeeds (or "already installed").

- [ ] **Step 2: Verify the CLI is available**

Run:
```powershell
yasbc --help
```
Expected: YASB CLI help text (lists subcommands including `enable-autostart`, `monitor-information`). If `yasbc` is not found, open a new shell so PATH refreshes, then retry.

- [ ] **Step 3: Create the symlink (elevated)**

Run the symlink-only path of the deploy script in an **admin** PowerShell:
```powershell
C:\Users\mint\dotfiles\deploy_windows.ps1 -SkipPackages -SkipFonts
```
(If those switches differ in the script, the equivalent single command is:
`New-Item -ItemType SymbolicLink -Path "$HOME\.config\yasb" -Value "C:\Users\mint\dotfiles\.config\yasb" -Force`.)

- [ ] **Step 4: Verify the symlink resolves to the dotfiles**

Run:
```powershell
(Get-Item "$HOME\.config\yasb").Target
```
Expected: `C:\Users\mint\dotfiles\.config\yasb` (and `LinkType` is `SymbolicLink`).

---

### Task 5: Integration & acceptance (launch, observe, tune, autostart)

> **Live/visual step.** This is the real acceptance test — observe the bar on screen. Admin not required for `yasb`/`yasbc`, but komorebi must be running. Hand to the user if the agent cannot observe the desktop.

**Files:**
- Possibly Modify (tuning only): `.config/komorebi/komorebi.json` (`global_work_area_offset.top`)

- [ ] **Step 1: Apply the komorebi config and restart its bar state**

Run:
```powershell
komorebic reload-configuration
```
If the old komorebi-bar is still visible, fully restart komorebi:
```powershell
komorebic stop; komorebic start
```
Expected: komorebi's own bar no longer appears.

- [ ] **Step 2: Launch YASB**

Run:
```powershell
yasb
```
Expected: a bar appears at the top of **every** monitor.

- [ ] **Step 3: Acceptance checks (observe)**

- [ ] Each monitor shows a YASB bar with workspaces on the left, clock centered.
- [ ] The clock reads 24-hour time (`HH:MM`) in the center. (No icon in v1 — a Nerd Font glyph can be prefixed later; avoid emoji.)
- [ ] Switching workspaces (Hyper+digit, per the keybinds design) updates the active highlight; empty workspaces are hidden; the active button uses the blue accent.
- [ ] No application window is hidden under the bar (work area is reserved), and there is **no doubled gap** at the top.

- [ ] **Step 4: Tune the offset if needed**

- If windows tile **under** the bar: increase `global_work_area_offset.top` in `komorebi.json` to the bar's pixel height, then `komorebic reload-configuration`.
- If there is a **doubled gap** (YASB self-reserves as an AppBar *and* komorebi reserves): set `global_work_area_offset.top` to `0` (let YASB own the reservation), `komorebic reload-configuration`.
- If `{name}` workspace labels render blank: change the three `label_workspace_*btn` values in `config.yaml` from `"{name}"` to `"{index}"` (YASB live-reloads via `watch_config`).

If you changed `komorebi.json` while tuning, commit it:
```bash
git add .config/komorebi/komorebi.json
git commit -m "fix(komorebi): tune YASB work-area offset"
```
If you changed `config.yaml` while tuning, commit it:
```bash
git add .config/yasb/config.yaml
git commit -m "fix(yasb): use {index} workspace labels"
```

- [ ] **Step 5: Enable launch-at-login**

Run:
```powershell
yasbc enable-autostart
```
Expected: confirmation that autostart is enabled (registry `Run` entry). Verify by checking the YASB tray menu shows "Disable Autostart", or re-running prints already-enabled.

---

### Task 6: Document the YASB bar

**Files:**
- Modify: `CLAUDE.md` (Windows Symlink Mappings table; Window Management section; Key Configuration Files table)
- Modify: `AGENTS.md` (Key File Locations table)

**Interfaces:** docs only — no runtime contract.

- [ ] **Step 1: Add YASB to the CLAUDE.md symlink-mappings table**

In the "Windows Symlink Mappings" table, after the `.config/komorebi` row, add:
```markdown
| `.config/yasb` | `$HOME\.config\yasb` (YASB status bar; replaces `komorebi --bar`) |
```

- [ ] **Step 2: Update the CLAUDE.md Window Management note**

In the "Window Management" section, change the Windows line to note YASB owns the bar:
```markdown
- **Windows:** Komorebi (tiling) + **YASB** status bar (per-monitor). Start komorebi with `komorebic start`, the bar with `yasb` (autostart via `yasbc enable-autostart`). komorebi's built-in bar is disabled (`bar_configurations: []`); it reserves the top strip via `global_work_area_offset`.
```

- [ ] **Step 3: Add YASB to the CLAUDE.md Key Configuration Files table**

After the Komorebi row, add:
```markdown
| YASB (Windows status bar) | `.config/yasb/config.yaml` (+ `styles.css`) |
```

- [ ] **Step 4: Add YASB to the AGENTS.md Key File Locations table**

After the Komorebi Config row, add:
```markdown
| YASB Status Bar (Windows) | `.config/yasb/` (→ `~/.config/yasb`) |
```

- [ ] **Step 5: Verify the docs mention YASB**

Run:
```bash
grep -c "yasb" CLAUDE.md AGENTS.md
```
Expected: non-zero counts for both files.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "docs(yasb): document YASB bar in CLAUDE.md and AGENTS.md"
```

---

## Notes for the executor

- **No worktree.** This change is tested live against the real desktop (symlinks into `~/.config`, running komorebi/YASB), so execute in the main checkout, not an isolated worktree.
- **Task order:** Tasks 1–3 are static and agent-verifiable (no admin). Tasks 4–5 need the live machine and an elevated shell for the symlink — hand to the user if the agent can't elevate or observe the desktop. Task 6 is docs.
- **Rollback** at any point: restore `bar_configurations` in `komorebi.json`, remove `global_work_area_offset`, `yasbc disable-autostart`, restart komorebi.
- **After acceptance**, remember this needs to reach **`master`** for the symlink to stay live across branch switches.
