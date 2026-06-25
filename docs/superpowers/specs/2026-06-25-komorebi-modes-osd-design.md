# Komorebi binding-modes + OSD — design

- **Date:** 2026-06-25
- **Status:** Approved design (brainstorming) → pending implementation plan
- **Scope:** **Windows only.** Adds AHK binding-modes (resize + service) and an on-screen mode indicator (OSD) on top of the existing Hyper/Meh scheme. macOS (yabai/skhd) parity is **deferred to a later session**. Companion to [Komorebi Hyper-key keybinds](./2026-06-25-komorebi-hyper-keybinds-design.md).

## Problem / motivation

The current `komorebi.ahk` (Hyper/Meh) is a flat chord scheme: every action is one direct chord. Cross-WM research across **i3, sway, bspwm, Hyprland, AeroSpace, GlazeWM** shows the whole ecosystem converges on the same idiom we already match (`$mod+key` focus, `$mod+Shift+key` move, `$mod+N` workspace) — but it also shows two patterns we *don't* yet use and that the modern WMs treat as best practice:

1. **Resize is a *mode*** — i3/sway (`$mod+r`), GlazeWM (`Alt+r`), Hyprland (submap) all enter a transient mode where bare `hjkl` resize and `Esc` exits. One-finger repeated nudging beats a 4-modifier arrow-chord per nudge, and it frees the arrow keys.
2. **Rare / destructive ops live behind a mode** — AeroSpace's "service mode" parks reload / reset-layout / close-all one modal keystroke away, keeping the daily layer tiny and unambiguous.

Both depend on a **visible mode indicator**, which the modern WMs render in their bar for free. Komorebi can't: `komorebi-bar`'s widgets are a fixed enum with no external-state/script widget, and its only command hook is mouse-triggered. So the indicator must be built separately.

## Decision

Adopt the **hybrid** structure (validated with the user against "stay flat" and "minimal-main + heavy-modes"):

- **Daily layer stays flat** — focus/move/workspace/send/float/monocle/close/flip/stack/cycle/monitors keep their current Hyper/Meh chords. **Muscle memory is unchanged.**
- **Add a resize mode** — `Hyper+r` → bare `hjkl` resize, `Shift` shrinks, `Esc`/`Enter`/timeout exit.
- **Add a service mode** — for rare/destructive ops (retile, pause, toggle-tiling, reload, restart).
- **Build an AHK GUI OSD** as the mode indicator — co-located with the mode state, no bar dependency.

### Why an AHK GUI, not the komorebi bar

`komorebi-bar` cannot render an AHK-driven mode: its widget set is a fixed enum (Komorebi/Time/Date/Update/Media/Storage/Memory/Network/Battery/CPU) with no generic external-state widget, and its `Command` hook only fires on mouse click/scroll, not as renderable output ([komorebi-bar schema](https://komorebi-bar.lgug2z.com/schema), [DeepWiki: bar widgets](https://deepwiki.com/LGUG2Z/komorebi/4.2.1-bar-configuration-and-widgets)). An AHK `Gui` is strictly better here anyway: mode state and its display live in the **same process**, so there is zero IPC, nothing to poll, nothing to desync, and it survives bar reloads. (A persistent corner indicator would be the only reason to switch to YASB — unnecessary for a transient badge.)

## Mode model

A single global `g_mode` (`""` / `"resize"` / `"service"`) drives AHK v2 `#HotIf` contexts. The flat Hyper/Meh chords remain **always active**; modes only add *bare-key* bindings that are live solely inside the mode. Bare `h` types normally everywhere except inside resize mode — so there is no conflict with the existing chords and the diff to the current config is additive.

```ahk
g_mode := ""                         ; reset on (re)load — never inherit a phantom mode

EnterMode(m) {
    global g_mode := m
    OSD_Show(m)
    SetTimer(ExitMode, -2500)        ; idle self-heal
}
ExitMode(*) {
    global g_mode := ""
    SetTimer(ExitMode, 0)
    OSD_Hide()
}

^!+#r::EnterMode("resize")           ; Hyper+r
^!+#`;::EnterMode("service")         ; Hyper+;  (frees the old ';' guard)
^!+#Escape::ExitMode()               ; panic exit — works from ANY state

#HotIf g_mode = "resize"
h::ResizeNudge("left","increase")
+h::ResizeNudge("left","decrease")
j::ResizeNudge("down","increase")
k::ResizeNudge("up","increase")
l::ResizeNudge("right","increase")
Enter::ExitMode()
Escape::ExitMode()
#HotIf

ResizeNudge(dir, d2) {
    Komorebic("resize-edge " dir " " d2)
    SetTimer(ExitMode, -2500)        ; each nudge resets the idle timer
}
```

## Robustness — five safeguards against "mode trap"

Modes reintroduce the one failure flat chords don't have (mode confusion — the vi lesson). These make it safe:

1. **Idle self-heal** — a 2.5 s inactivity timer auto-exits; every mode keypress resets it. Walk away mid-resize and it clears itself.
2. **`Esc` / `Enter` always exit** — cancel or confirm, both leave.
3. **Panic exit** — `Hyper+Escape` force-resets `g_mode` from any state; you can never get stuck.
4. **Reset on (re)load** — `g_mode := ""` at script top, so an AHK reload never leaves a phantom mode.
5. **OSD never steals focus, never gets tiled** — the GUI is `+E0x08000000` (WS_EX_NOACTIVATE) and shown `NoActivate`, because komorebi acts on the *focused* window; it is also registered in komorebi's `floating_applications` so komorebi doesn't try to tile the badge itself.

## OSD — themed, click-through badge

```ahk
OSD_Show(m) {
    global osd := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 +E0x20")
    osd.BackColor := "303446"                      ; Catppuccin Frappe base
    osd.SetFont("s11 cC6D0F5", "JetBrains Mono")   ; matches bar font
    osd.Add("Text",, Legend(m))
    osd.Show("NoActivate yCenter Center")
}
```

Appears on enter, vanishes on exit; one-line legend per mode:

- **Resize:** `⟨ RESIZE ⟩  h j k l nudge · ⇧ shrink · esc done`
- **Service:** `⟨ SERVICE ⟩  r retile · p pause · t tiling · o reload · ⌫ restart · esc`

Themed to **Catppuccin Frappe** to match the WM/border (note: the bar is currently Base16 "Ashes" while `komorebi.json` is Frappe — pre-existing mismatch; OSD matches the WM).

## Keymap changes

**Moves out of flat chords (into modes):**

| Action | Was | Now |
|---|---|---|
| Resize | `Hyper+arrows` | resize mode (`Hyper+r` → `hjkl`) |
| Retile | `Meh+r` | service mode `r` |
| Toggle-pause | `Meh+q` | service mode `p` |
| Restart komorebi | `Hyper+Backspace` | service mode `⌫` |
| Reload config | — | service mode `o` (`replace-configuration`) |
| Toggle-tiling | — | service mode `t` |

**New daily adds (the universal wins):**

- `Hyper+Tab` → `focus-last-workspace` (workspace back-and-forth; the AeroSpace `Alt+Tab` analog, native in komorebi).
- `Meh+Enter` → `promote` (make-main; matches komorebi's own example config).
- `Hyper+arrows` → **freed** (resize vacated it); left open.

**Unchanged:** all focus/move/workspace/send/float/monocle/close/minimize/flip/stack/cycle-focus/cycle-stack/monitor chords from the Hyper/Meh spec.

## Scratchpad — deliberate skip

Komorebi has no native scratchpad/special-workspace (unlike sway/Hyprland/yabai). The clean Windows answer is **WezTerm's quake/dropdown**, handled in the terminal config — not a komorebi hack. Out of scope here; flagged so the omission is a conscious choice.

## Risks & mitigations

- **Mode confusion** — the five safeguards above; modes are reserved for bursty-repeated (resize) or rare-and-many (service) ops only, never single high-frequency actions.
- **AHK `#HotIf` capture** — bare `hjkl` are globally swallowed *while in resize mode*; the timeout + `Esc`/`Enter` + panic-exit bound the exposure.
- **OSD focus/tiling** — no-activate + `floating_applications` rule; verified in acceptance.
- **AHK v2 ↔ komorebi** — existing setup on `v2.0.2`; modes use only core `#HotIf`/`Gui`/`SetTimer`, no exotic features.
- **Cross-platform drift** — explicitly deferred; macOS stays on its current scheme until its own session.

## Acceptance criteria

1. `Hyper+r` shows the resize OSD; bare `hjkl` resize the focused window; `Shift` shrinks; `Esc`/`Enter`/2.5 s-idle all exit and hide the OSD.
2. `Hyper+;` shows the service OSD; `r`/`p`/`t`/`o`/`⌫` perform retile/pause/toggle-tiling/reload/restart; `Esc` exits.
3. `Hyper+Escape` exits from any mode (panic).
4. After an AHK reload mid-mode, `g_mode` is `""` (no phantom mode).
5. The OSD never takes focus (the focused window is unchanged when it appears) and komorebi never tiles it.
6. All daily Hyper/Meh chords from the prior spec behave exactly as before; `Hyper+Tab` switches to the last workspace; `Meh+Enter` promotes.
7. `komorebi.ahk` still has no bare-Alt bindings (Zellij's Alt namespace stays clean).

## Open items (settle in the plan)

- Final trigger keys: `Hyper+r` (resize) / `Hyper+;` (service) — or alternatives.
- Resize step size; whether arrows mirror `hjkl` inside resize mode.
- Exact service-mode roster (which rare ops move vs. stay flat).
- Whether `Hyper+arrows` (freed) gets a new assignment now or stays open.

## Sources

- Cross-WM convergence: [i3 User's Guide](https://i3wm.org/docs/userguide.html) · [sway(5)](https://man.archlinux.org/man/sway.5) · [AeroSpace guide (binding modes)](https://nikitabobko.github.io/AeroSpace/guide) · [Hyprland binds](https://wiki.hypr.land/Configuring/Basics/Binds/) · [GlazeWM sample config](https://github.com/glzr-io/glazewm/blob/main/resources/assets/sample-config.yaml)
- Komorebi bar limits: [komorebi-bar schema](https://komorebi-bar.lgug2z.com/schema) · [DeepWiki: bar widgets](https://deepwiki.com/LGUG2Z/komorebi/4.2.1-bar-configuration-and-widgets)
- Komorebi CLI: [komorebic reference](https://komorebi.lgug2z.com/reference/komorebic-windows/)
- AHK v2: [`#HotIf`](https://www.autohotkey.com/docs/v2/lib/_HotIf.htm) · [`Gui`](https://www.autohotkey.com/docs/v2/lib/Gui.htm)
- Prior art: [Komorebi Hyper-key keybinds design](./2026-06-25-komorebi-hyper-keybinds-design.md) · [[Hyper Key as a Tiling-WM Modifier on Windows]]
