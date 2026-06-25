# Komorebi Keybindings Manual

## Overview

This document describes the keybindings for the **komorebi** tiling window manager on Windows, driven by AutoHotkey v2 (`komorebi.ahk`). The scheme is built on two custom modifier keys produced as single physical keys by a ZSA/QMK keyboard:

- **Hyper** = `Ctrl+Alt+Shift+Win` (AHK `^!+#`) → **focus / act** on the current window
- **Meh** = `Ctrl+Alt+Shift` (AHK `^!+`) → **move / relocate** the window

`Alt` is left **entirely free** for the terminal (Zellij) — there are no bare-Alt bindings. The split exists because Hyper already contains Shift, so the i3 idiom `$mod+key` (focus) / `$mod+Shift+key` (move) is impossible; the move layer gets its own physical key (Meh) instead. See [`docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md`](../../docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md).

> **Status:** Live — the flat Hyper/Meh layers, the **resize mode**, **service mode**, the daily adds (`Hyper+Tab`, `Meh+Enter`), and the **OSD** are all implemented in `komorebi.ahk` and verified on the live WM. Design: [`2026-06-25-komorebi-modes-osd-design.md`](../../docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md).

---

## The mental model

Think i3, with the modifier lifted off `Alt`:

| i3 / sway / AeroSpace | Here | Meaning |
|---|---|---|
| `$mod + key` | **Hyper + key** | focus / act |
| `$mod+Shift + key` | **Meh + key** | move / relocate |
| `$mod + r` → resize mode | **Hyper + r** | enter resize mode |

Everything you do daily is a flat chord (no modes). Resize and rare/destructive ops live behind a **mode** so the daily layer stays small — exactly how i3/sway/GlazeWM/AeroSpace structure it.

---

## Hyper layer — focus / act

| Keybind | Action | komorebic |
|---------|--------|-----------|
| `Hyper + H/J/K/L` | Focus window left/down/up/right | `focus left/down/up/right` |
| `Hyper + 1`–`0` | Focus workspace 1–10 (I–X) | `focus-workspace 0`–`9` |
| `Hyper + [` / `]` | Cycle focus previous / next | `cycle-focus previous/next` |
| `Hyper + ,` / `.` | Focus monitor 0 / 1 | `focus-monitor 0/1` |
| `Hyper + Tab` | Switch to last workspace (back-and-forth) | `focus-last-workspace` |
| `Hyper + T` | Toggle float (centered) | `toggle-float` |
| `Hyper + F` | Toggle monocle (zoom) | `toggle-monocle` |
| `Hyper + X` / `Y` | Flip layout horizontal / vertical | `flip-layout horizontal/vertical` |
| `Hyper + C` | Cycle layout next | `cycle-layout next` |
| `Hyper + Q` | Close window | `close` |
| `Hyper + M` | Minimize window | `minimize` |
| `Hyper + Home` | Suspend AHK hotkeys (toggle) | — |

---

## Meh layer — move / relocate

| Keybind | Action | komorebic |
|---------|--------|-----------|
| `Meh + H/J/K/L` | Move window left/down/up/right | `move left/down/up/right` |
| `Meh + 1`–`0` | Send window → workspace 1–10 | `move-to-workspace 0`–`9` |
| `Meh + P` / `N` | Send window → prev / next workspace | `cycle-move-to-workspace previous/next` |
| `Meh + ,` / `.` | Send window → monitor 0 / 1 | `move-to-monitor 0/1` |
| `Meh + ←↓↑→` | Stack window left/down/up/right | `stack left/down/up/right` |
| `Meh + ;` | Unstack window | `unstack` |
| `Meh + [` / `]` | Cycle stack previous / next | `cycle-stack previous/next` |
| `Meh + C` | Cycle layout previous | `cycle-layout previous` |
| `Meh + Enter` | Promote to main tile | `promote` |

---

## Resize mode

Tap **`Hyper + R`** to enter. While in the mode, bare keys resize the **focused** window — no modifier held. An OSD badge shows the active mode.

| Key (in mode) | Action | komorebic |
|---------|--------|-----------|
| `H/J/K/L` | Grow edge left/down/up/right | `resize-edge left/down/up/right increase` |
| `Shift + H/J/K/L` | Shrink edge left/down/up/right | `resize-edge … decrease` |
| `Esc` / `Enter` | Exit the mode | — |
| *(2.5 s idle)* | Auto-exit (self-heal) | — |

> Why a mode? Repeated nudging with one finger beats a 4-modifier arrow-chord per nudge, and it frees the arrow keys. This is the i3/sway/GlazeWM resize-mode idiom.

---

## Service mode

Tap **`Hyper + ;`** to enter. Houses rare / destructive ops so they don't clutter the daily layer (AeroSpace's "service mode" pattern). OSD badge shows the mode.

| Key (in mode) | Action | komorebic |
|---------|--------|-----------|
| `R` | Retile / reset layout | `retile` |
| `P` | Toggle pause (freeze tiling) | `toggle-pause` |
| `T` | Toggle tiling for workspace | `toggle-tiling` |
| `O` | Reload configuration | `replace-configuration` |
| `Backspace` | Restart komorebi | `stop` + `start` |
| `Esc` / `Enter` | Exit the mode | — |

---

## Modes — safety

Modes can't trap you. Five safeguards:

1. **Idle self-heal** — 2.5 s of no mode-key press auto-exits.
2. **`Esc` / `Enter` always exit.**
3. **Panic exit** — `Hyper + Escape` force-exits from *any* state.
4. **Reset on reload** — an AHK reload never leaves you stuck in a phantom mode.
5. **OSD never steals focus and is never tiled** — it's a no-activate tool window (`WS_EX_NOACTIVATE` + `ToolWindow`), so komorebi doesn't manage it. _(A belt-and-suspenders `floating_applications` rule in `komorebi.json` is **deferred** — unneeded so far, since the badge already floats untiled.)_

While in a mode, the mode's bare keys (e.g. `hjkl` in resize) are captured — that's the point — so the OSD badge is your reminder to `Esc` out before typing.

---

## On-screen mode indicator (OSD)

A small always-on-top, click-through badge (AHK `Gui`) appears when a mode is active and vanishes on exit. Themed Catppuccin Frappe / JetBrains Mono to match the WM border. It does **not** live in the komorebi bar (the bar has no external-state widget) — it's self-contained in `komorebi.ahk`, so it can't desync and survives bar reloads.

```
⟨ RESIZE ⟩   h j k l nudge · ⇧ shrink · esc done
⟨ SERVICE ⟩  r retile · p pause · t tiling · o reload · ⌫ restart · esc
```

---

## Quick Reference Card

**Hyper = focus/act · Meh = move/relocate** (Hyper = `Ctrl+Alt+Shift+Win`, Meh = `Ctrl+Alt+Shift`)

| Group | Keys |
|-------|------|
| **Focus** | `Hyper + hjkl` dir · `Hyper + 1‑0` workspace · `Hyper + [ ]` cycle · `Hyper + Tab` last-ws |
| **Move** | `Meh + hjkl` dir · `Meh + 1‑0` send-ws · `Meh + p/n` send prev/next · `Meh + Enter` promote |
| **Layout** | `Hyper + x/y` flip · `Hyper + c` / `Meh + c` cycle next/prev · `Hyper + f` monocle · `Hyper + t` float |
| **Stack** | `Meh + ←↓↑→` stack · `Meh + ;` unstack · `Meh + [ ]` cycle stack |
| **Monitors** | `Hyper + , .` focus 0/1 · `Meh + , .` send 0/1 |
| **Window** | `Hyper + q` close · `Hyper + m` minimize |
| **Resize mode** | `Hyper + r` → `hjkl` nudge · `⇧` shrink · `esc` exit |
| **Service mode** | `Hyper + ;` → `r` retile · `p` pause · `t` tiling · `o` reload · `⌫` restart |
| **Escape hatch** | `Hyper + Escape` panic-exit any mode |

---

## Usage Examples

### Resize a window precisely
1. Focus the window (`Hyper + L` etc.).
2. `Hyper + R` → the **RESIZE** badge appears.
3. Tap `L` `L` `L` to grow the right edge; `Shift + J` to shrink the bottom.
4. `Esc` (or just stop — it auto-exits after 2.5 s).

### Throw a window to the next monitor and follow it
1. `Meh + .` → sends the focused window to monitor 1.
2. `Hyper + .` → moves your focus to monitor 1.

### Reset a mangled layout
1. `Hyper + ;` → the **SERVICE** badge appears.
2. `R` → retiles everything back to the workspace layout.
3. `Esc`.

---

## Multi-monitor

`komorebi.json` configures 3 monitors (BSP / Rows / BSP) with 10 workspaces each (I–X). Focus/send are bound for monitors **0 and 1** (`Hyper/Meh + ,` `.`); a third-monitor bind can be added if needed.

---

## Configuration File Reference

| File | Purpose |
|------|---------|
| `komorebi.ahk` | All keybindings (this manual) — AHK v2, symlinked via `KOMOREBI_CONFIG_HOME` |
| `komorebi.json` | WM config: monitors, workspaces, layouts, borders, theme, rules |
| `komorebi.bar.json` | Bar config (+ `komorebi.bar.monitor1/2.json` per-monitor) |
| `applications.json` | App-specific window rules |

Editing `komorebi.ahk` in the repo is **live** (it's symlinked). Apply changes by re-running the script; or use service mode `O` (`replace-configuration`) for `komorebi.json` changes.

### Customisation
- Daily chords: edit the `Hyper (^!+#)` / `Meh (^!+)` sections of `komorebi.ahk`.
- Modes: edit the `#HotIf g_mode = "…"` blocks.
- OSD look: edit `OSD_Show()` (colors / font / position).

---

## Troubleshooting

### Tapping Hyper alone pops an Office/Copilot dialog
The bare 4-modifier chord is reserved by Windows. Neutralize per-user + reversibly (in `deploy_windows.ps1`):
`REG ADD HKCU\Software\Classes\ms-officeapp\Shell\Open\Command /t REG_SZ /d rundll32`

### A key types instead of running its action / a mode key won't type
You're probably **in a mode** — look for the OSD badge and press `Esc` (or `Hyper + Escape`). Modes capture their bare keys by design.

### An Alt combo doesn't reach the terminal
It shouldn't be bound here — `komorebi.ahk` has **no bare-Alt bindings**. If one appears, remove it; Alt belongs to Zellij.

### Hotkeys stopped working
`Hyper + Home` toggles AHK suspend — press it again to re-enable. Or restart via service mode `Backspace`.

---

## Notes

- Keys are case-insensitive for letters; `Shift` is a distinct modifier inside modes (shrink vs. grow).
- The semicolon is escaped `` `; `` in AHK source.
- Hyper/Meh require the QMK keyboard; a board-less machine needs a `CapsLock → Hyper` remap (AHK or kanata) to restore them.

## See Also

- [Komorebi Hyper-key keybinds design](../../docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md)
- [Komorebi modes + OSD design](../../docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md)
- [komorebi docs](https://lgug2z.github.io/komorebi/) · [komorebic CLI reference](https://komorebi.lgug2z.com/reference/komorebic-windows/)
- [AutoHotkey v2 docs](https://www.autohotkey.com/docs/v2/)
