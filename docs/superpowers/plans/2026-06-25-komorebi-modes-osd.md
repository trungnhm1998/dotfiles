# Komorebi binding-modes + OSD — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add resize + service binding-modes and an AHK-GUI on-screen mode indicator (OSD) to the komorebi/AHK setup, plus two daily binds, on Windows.

**Architecture:** A single global `g_mode` drives AHK v2 `#HotIf` contexts. The existing flat Hyper/Meh chords stay always-active; modes only add *bare-key* hotkeys that are live solely inside a mode. The OSD is a self-contained AHK `Gui` (no komorebi-bar dependency) shown on mode-enter and destroyed on exit. Rare/destructive ops move from flat chords into a service mode.

**Tech Stack:** AutoHotkey v2.0.2 (`komorebi.ahk`), komorebi (`komorebic.exe`), komorebi static config (`komorebi.json`).

**Source spec:** `docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md`

## Global Constraints

- **AutoHotkey v2.0.2** syntax only (`#Requires AutoHotkey v2.0.2` is already at the top of the file).
- **No bare-Alt (`!`) bindings** anywhere — `Alt` belongs to the terminal (Zellij). All WM binds use the `^!+#` (Hyper) or `^!+` (Meh) prefixes, or bare keys *inside a mode*.
- **Windows only.** macOS (yabai/skhd) is explicitly out of scope this session.
- **OSD theme:** Catppuccin Frappe — base `#303446`, text `#c6d0f5`, font `JetBrains Mono` (match the WM border/`komorebi.json`).
- **OSD window must never take focus** (`WS_EX_NOACTIVATE` = `0x08000000`, shown `NoActivate`) and must be registered floating in `komorebi.json` so komorebi never tiles it.
- **Modes must be un-trappable:** idle self-heal timer (2500 ms) + `Esc`/`Enter` exit + `Hyper+Escape` panic exit + `g_mode` reset on script load.
- **Semicolon is escaped** `` `; `` in AHK source.

## Verification model (read this)

`komorebi.ahk` has no practical unit-test harness, so each task is verified two ways:
1. **Syntax validation (automatable):** `AutoHotkey64.exe /validate <script>` → exit code `0`.
2. **Behavioural acceptance (manual):** reload the script and press the keys, observing the result. Steps marked **(manual)** require a human at the keyboard — they map directly to the spec's acceptance criteria.

Throughout, `AHK` = `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (adjust if installed elsewhere — find via `(Get-Command AutoHotkey*).Source` or the Start-Menu shortcut). `$CFG` = `$env:KOMOREBI_CONFIG_HOME` (the symlinked `.config/komorebi`).

## File Structure

- `.config/komorebi/komorebi.ahk` — all keybindings + the new mode engine/OSD (the bulk of the work).
- `.config/komorebi/komorebi.json` — add one `floating_applications` entry for the OSD window.
- `.config/komorebi/KEYBINDS.md` — flip the 🆕 "designed" markers to "live" at the end.
- `docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md`, `.config/komorebi/README.md` — already written during brainstorming; committed in Task 0.

---

### Task 0: Commit the design artifacts (clean baseline)

**Files:**
- Commit: `docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md`, `.config/komorebi/KEYBINDS.md`, `.config/komorebi/README.md`

- [ ] **Step 1: Stage and commit the design docs**

```bash
git add docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md \
        .config/komorebi/KEYBINDS.md .config/komorebi/README.md
git commit -m "docs(komorebi): modes+OSD design spec and keybinds manual"
```

> On branch `feat/zellij-windows` (consistent with the existing Hyper/Meh work). Move to a fresh branch first if you prefer isolation.

---

### Task 1: Mode engine + OSD + resize mode

**Files:**
- Modify: `.config/komorebi/komorebi.ahk` (add engine after the `Komorebic()` function; remove the 4 Hyper+arrow resize binds and the `^!+#r` guard; append the resize `#HotIf` block)

**Interfaces:**
- Produces: globals `g_mode` (`""`|`"resize"`|`"service"`), `osd`; functions `EnterMode(m)`, `ExitMode(*)`, `OSD_Show(m)`, `OSD_Hide(*)`, `Legend(m)`, `ResizeNudge(dir, delta)`. Tasks 2–4 reuse `EnterMode`/`ExitMode`/`Komorebic`.

- [ ] **Step 1: Add the mode engine** immediately after the `Komorebic()` function (after line 12):

```ahk
; ============================================================
; Binding modes — engine + OSD
;   g_mode: "" | "resize" | "service"
;   Spec: docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md
; ============================================================
g_mode := ""        ; reset on (re)load — never inherit a phantom mode
osd := ""

EnterMode(m) {
    global g_mode := m
    OSD_Show(m)
    SetTimer(ExitMode, -2500)         ; idle self-heal (one-shot)
}

ExitMode(*) {
    global g_mode := ""
    SetTimer(ExitMode, 0)             ; cancel any pending self-heal
    OSD_Hide()
}

Legend(m) {
    switch m {
        case "resize":  return "⟨ RESIZE ⟩    h j k l nudge  ·  ⇧ shrink  ·  esc done"
        case "service": return "⟨ SERVICE ⟩   r retile  ·  p pause  ·  t tiling  ·  o reload  ·  ⌫ restart  ·  esc"
    }
    return ""
}

OSD_Show(m) {
    global osd
    OSD_Hide()                        ; never stack two badges
    osd := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 +E0x20")  ; no-activate + click-through
    osd.Title := "KomorebiModeOSD"    ; matched by the komorebi floating rule (Task 4)
    osd.BackColor := "303446"         ; Catppuccin Frappe base
    osd.MarginX := 16
    osd.MarginY := 10
    osd.SetFont("s11 cC6D0F5", "JetBrains Mono")
    osd.Add("Text", , Legend(m))
    osd.Show("NoActivate AutoSize yCenter Center")
}

OSD_Hide(*) {
    global osd
    if (osd) {
        try osd.Destroy()
        osd := ""
    }
}

ResizeNudge(dir, delta) {
    Komorebic("resize-edge " dir " " delta)
    SetTimer(ExitMode, -2500)         ; each nudge re-arms the idle timer
}

; --- always-active mode triggers ---
^!+#r::EnterMode("resize")            ; Hyper+r
^!+#Escape::ExitMode()                ; panic exit — works from ANY state
```

- [ ] **Step 2: Remove the old flat resize binds.** Delete these four lines from the Hyper section (the `; Resize (was ...)` block):

```ahk
^!+#Left::Komorebic("resize-edge left increase")
^!+#Down::Komorebic("resize-edge down increase")
^!+#Up::Komorebic("resize-edge up increase")
^!+#Right::Komorebic("resize-edge right increase")
```

- [ ] **Step 3: Remove the now-conflicting `r` guard.** In the guards block, delete the line `^!+#r::return` (it would duplicate the new `^!+#r` trigger — AHK errors on duplicate hotkeys). Leave `^!+#p::return` and `^!+#n::return`.

- [ ] **Step 4: Append the resize mode hotkeys** at the very end of the file:

```ahk
; ============================================================
; Mode hotkeys — bare keys, live ONLY inside a mode
; ============================================================
#HotIf g_mode = "resize"
h::ResizeNudge("left", "increase")
j::ResizeNudge("down", "increase")
k::ResizeNudge("up", "increase")
l::ResizeNudge("right", "increase")
+h::ResizeNudge("left", "decrease")
+j::ResizeNudge("down", "decrease")
+k::ResizeNudge("up", "decrease")
+l::ResizeNudge("right", "decrease")
Enter::ExitMode()
Escape::ExitMode()
#HotIf
```

- [ ] **Step 5: Validate syntax**

Run (PowerShell): `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"; $LASTEXITCODE`
Expected: prints `0` (no syntax error dialog).

- [ ] **Step 6: Reload and verify behaviour (manual)**

Reload: `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"` (➞ `#SingleInstance Force` replaces the running instance).
Then check (spec criteria 1, 3, 5):
- `Hyper+r` → the **RESIZE** badge appears, centered, and does **not** steal focus (the focused window stays focused).
- bare `h/j/k/l` grow the focused window's edges; `Shift+h/j/k/l` shrink them.
- `Esc`, `Enter`, and 2.5 s of inactivity each exit and hide the badge.
- `Hyper+Escape` exits immediately mid-resize.
- bare `h` types normally when **not** in resize mode.

- [ ] **Step 7: Commit**

```bash
git add .config/komorebi/komorebi.ahk
git commit -m "feat(komorebi): mode engine + OSD + resize mode"
```

---

### Task 2: Service mode

**Files:**
- Modify: `.config/komorebi/komorebi.ahk` (add the `^!+#`;`` trigger; remove the `;` guard and three flat rare-op binds; append the service `#HotIf` block)

**Interfaces:**
- Consumes: `EnterMode`/`ExitMode`/`Komorebic` (Task 1).

- [ ] **Step 1: Add the service-mode trigger** next to the resize trigger in the engine section:

```ahk
^!+#`;::EnterMode("service")          ; Hyper+;  (semicolon escaped)
```

- [ ] **Step 2: Remove the now-conflicting `;` guard.** Delete `^!+#`;`::return` from the guards block (replaced by the trigger above).

- [ ] **Step 3: Remove the three flat rare-op binds** (they move into service mode):
  - In the Meh section delete `^!+r::Komorebic("retile")` and `^!+q::Komorebic("toggle-pause")`.
  - In the Hyper section delete the whole `^!+#Backspace::{ ... }` restart block (the `stop` / `Sleep` / `start` block).

- [ ] **Step 4: Append the service mode hotkeys** after the resize `#HotIf` block at the end of the file:

```ahk
#HotIf g_mode = "service"
r:: {
    Komorebic("retile")
    ExitMode()
}
p:: {
    Komorebic("toggle-pause")
    ExitMode()
}
t:: {
    Komorebic("toggle-tiling")
    ExitMode()
}
o:: {
    cfg := EnvGet("KOMOREBI_CONFIG_HOME") "\komorebi.json"
    Komorebic('replace-configuration "' cfg '"')
    ExitMode()
}
Backspace:: {
    RunWait("komorebic.exe stop", , "Hide")
    Sleep(1000)
    RunWait("komorebic.exe start", , "Hide")
    ExitMode()
}
Enter::ExitMode()
Escape::ExitMode()
#HotIf
```

- [ ] **Step 5: Validate syntax**

Run: `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"; $LASTEXITCODE`
Expected: `0`.

- [ ] **Step 6: Reload and verify behaviour (manual)** — spec criterion 2:
- `Hyper+;` → the **SERVICE** badge appears.
- `r` retiles, `p` toggles pause, `t` toggles tiling, `o` reloads `komorebi.json`, `Backspace` restarts komorebi — each then exits the mode.
- `Esc` exits without acting.

- [ ] **Step 7: Commit**

```bash
git add .config/komorebi/komorebi.ahk
git commit -m "feat(komorebi): service mode for rare/destructive ops"
```

---

### Task 3: Daily adds + guard hygiene

**Files:**
- Modify: `.config/komorebi/komorebi.ahk` (add `Hyper+Tab`, `Meh+Enter`, and a `Hyper+Enter` guard)

- [ ] **Step 1: Verify the command exists first**

Run: `komorebic focus-last-workspace`
Expected: no "unrecognized subcommand" error (it switches to the previous workspace). If it errors, your komorebi predates the command — stop and report; do not bind it.

- [ ] **Step 2: Add the two daily binds + the guard.** In the Hyper section add:

```ahk
^!+#Tab::Komorebic("focus-last-workspace")   ; workspace back-and-forth
^!+#Enter::return                            ; guard: stop Hyper+Enter bleeding into Meh+Enter
```

In the Meh section add:

```ahk
^!+Enter::Komorebic("promote")               ; promote focused window to main
```

- [ ] **Step 3: Validate syntax**

Run: `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"; $LASTEXITCODE`
Expected: `0`.

- [ ] **Step 4: Reload and verify behaviour (manual)** — spec criterion 6:
- `Hyper+Tab` jumps to the last-used workspace (press twice → back where you started).
- `Meh+Enter` promotes the focused window to the main tile.
- `Hyper+Enter` does nothing (no accidental promote).

- [ ] **Step 5: Commit**

```bash
git add .config/komorebi/komorebi.ahk
git commit -m "feat(komorebi): Hyper+Tab last-workspace, Meh+Enter promote"
```

---

### Task 4: Register the OSD window as floating in komorebi

**Files:**
- Modify: `.config/komorebi/komorebi.json:172-178` (the `floating_applications` array)

- [ ] **Step 1: Add the OSD float rule.** Change the `floating_applications` array so it also matches the OSD window title:

```json
  "floating_applications": [
    {
      "kind": "Exe",
      "id": "dopus.exe",
      "matching_strategy": "Equals"
    },
    {
      "kind": "Title",
      "id": "KomorebiModeOSD",
      "matching_strategy": "Equals"
    }
  ],
```

- [ ] **Step 2: Reload komorebi config**

Run: `komorebic replace-configuration "$env:KOMOREBI_CONFIG_HOME\komorebi.json"`
Expected: no error; komorebi keeps running.

- [ ] **Step 3: Verify the OSD is never tiled (manual)** — spec criterion 5:
- Trigger `Hyper+r`. The badge floats centered; komorebi does **not** carve a tile for it (surrounding windows don't reflow), and focus stays on your window.

- [ ] **Step 4: Commit**

```bash
git add .config/komorebi/komorebi.json
git commit -m "fix(komorebi): float the mode OSD window so it isn't tiled"
```

---

### Task 5: Flip the manual to live + final acceptance

**Files:**
- Modify: `.config/komorebi/KEYBINDS.md` (the Status note + 🆕 markers)

- [ ] **Step 1: Update the Status note.** Replace the blockquote under the title:

```markdown
> **Status:** Live. The flat Hyper/Meh layers, the **resize mode**, **service mode**, and the **OSD** are all implemented in `komorebi.ahk`. Design: [`2026-06-25-komorebi-modes-osd-design.md`](../../docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md).
```

- [ ] **Step 2: Strip the 🆕 markers.** Remove the `🆕` glyph from the section headings and table rows (`## Resize mode`, `## Service mode`, `## Modes — safety`, `## On-screen mode indicator (OSD)`, and the `Hyper + Tab` / `Meh + Enter` / Quick-Reference rows). The content stays; only the "designed/new" framing goes.

- [ ] **Step 3: Full syntax validation**

Run: `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"; $LASTEXITCODE`
Expected: `0`.

- [ ] **Step 4: Full acceptance pass (manual)** — run every spec criterion 1–7 once, end to end, including: criterion 4 — reload the script *while in a mode* and confirm you're not stuck (`g_mode` resets to `""`); criterion 7 — confirm `komorebi.ahk` still contains **zero** bare-Alt (`!`) bindings outside the `^!+`/`^!+#` prefixes (search the file for `::` lines).

- [ ] **Step 5: Commit**

```bash
git add .config/komorebi/KEYBINDS.md
git commit -m "docs(komorebi): mark modes + OSD live in keybinds manual"
```

---

## Self-Review

**1. Spec coverage:**
- Mode model (`g_mode` + `#HotIf`) → Task 1. ✓
- Five robustness safeguards (idle timer, Esc/Enter, panic, reset-on-load, no-activate+float) → Task 1 (timer/Esc/panic/reset/no-activate) + Task 4 (float rule); reset-on-load verified in Task 5 step 4. ✓
- OSD (Gui, theme, legends) → Task 1. ✓
- Keymap moves (resize→mode, retile/pause/restart→service, reload added) → Tasks 1–2. ✓
- Daily adds (Hyper+Tab, Meh+Enter) + freed Hyper+arrows → Task 3 (arrows freed by Task 1 removal). ✓
- "No bare-Alt" invariant → Task 5 step 4. ✓
- Scratchpad → explicitly out of scope (spec), no task. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete AHK/JSON; manual steps enumerate exact keys + expected results. ✓

**3. Type/name consistency:** `EnterMode`/`ExitMode`/`OSD_Show`/`OSD_Hide`/`Legend`/`ResizeNudge` defined in Task 1 and reused with identical names in Tasks 2–4; OSD `Title` `"KomorebiModeOSD"` set in Task 1 matches the `floating_applications` `id` in Task 4. ✓

**Open items deferred to execution (from the spec):** resize step size (default = komorebi's `resize-edge` increment), whether arrows mirror `hjkl` in resize mode (not bound — `hjkl` only), reassigning the freed `Hyper+arrows` (left open). Adjust during Task 1 manual testing if the increment feels wrong.
