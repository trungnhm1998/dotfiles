#Requires AutoHotkey v2.0.2
#SingleInstance Force

; Komorebi hotkeys — Hyper/Meh scheme.
; Design: docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md
;   Hyper = ^!+#  (Ctrl+Alt+Shift+Win)  -> focus / act on the current window
;   Meh   = ^!+   (Ctrl+Alt+Shift)      -> move / relocate the window
; Alt is intentionally left ENTIRELY free for the terminal (Zellij). No bare-Alt binds.

Komorebic(cmd) {
    RunWait(format("komorebic.exe {}", cmd), , "Hide")
}

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
        case "service": return "⟨ SERVICE ⟩   r retile  ·  p pause  ·  t tiling  ·  f fullscreen  ·  o reload  ·  d drift  ·  ⌫ restart  ·  x gaming off  ·  g gaming profile  ·  esc"
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

OSD_Flash(text) {                     ; transient badge (self-hides) — reuses the mode-OSD look
    global osd
    OSD_Hide()
    osd := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 +E0x20")
    osd.Title := "KomorebiModeOSD"
    osd.BackColor := "303446"
    osd.MarginX := 16
    osd.MarginY := 10
    osd.SetFont("s11 cC6D0F5", "JetBrains Mono")
    osd.Add("Text", , text)
    osd.Show("NoActivate AutoSize yCenter Center")
    SetTimer(OSD_Hide, -1200)         ; one-shot auto-hide
}

ResizeNudge(dir, delta) {
    Komorebic("resize-edge " dir " " delta)
    SetTimer(ExitMode, -2500)         ; each nudge re-arms the idle timer
}

; ============================================================
; OLED burn-in guard — orbit the always-on YASB bars
;   Spec: docs/superpowers/specs/2026-06-26-yasb-oled-burn-in-guard-design.md
;   Drifts every yasb.exe bar around a small ellipse (down/right only, so the
;   top never clips) to spread OLED subpixel wear. Anchored to each monitor's
;   top-left every tick -> reload/restart-proof. Skips hidden bars (fullscreen
;   games). OnExit snaps bars home so quitting never strands them offset.
;   Three presets cycled by service-mode `d`: static (pinned home) / invisible
;   (~4px, imperceptible — default) / aggressive (~16px, away-from-keyboard).
;   Radius is bounded by *perceptibility*, not clipping: yasb padding.left/right
;   is 30 — ample headroom (pills only clip if a radius exceeds 30).
; ============================================================
; three drift presets, cycled by service-mode `d`  (static -> invisible -> aggressive -> wrap)
oled_presets := [
    {name: "static",     Rx: 0,  Ry: 0,  Tp: 150},   ; pinned home — perfect alignment, no spread
    {name: "invisible",  Rx: 4,  Ry: 4,  Tp: 150},   ; ~4px, ~0.17 px/s — imperceptible (default)
    {name: "aggressive", Rx: 16, Ry: 16, Tp: 100},   ; ~16px — max spread, for away-from-keyboard
]
oled_idx := 2                                ; default = invisible
oled_mode := oled_presets[oled_idx].name
oled_Rx := oled_presets[oled_idx].Rx
oled_Ry := oled_presets[oled_idx].Ry
oled_Tp := oled_presets[oled_idx].Tp

SetTimer(OLED_Orbit, 1000)        ; 1 Hz (~1px/tick here); lower to 250 for smoother
OnExit(OLED_Restore)

OLED_Orbit(*) {
    global oled_Rx, oled_Ry, oled_Tp
    static PI := 3.141592653589793
    ang := 2 * PI * Mod(A_TickCount / 1000, oled_Tp) / oled_Tp
    dx := Round(oled_Rx * Sin(ang))            ; -Rx .. +Rx  (centered horizontally)
    dy := Round(oled_Ry * (1 - Cos(ang)) / 2)  ;   0 .. +Ry  (downward only -> no top clip)
    OLED_PlaceBars(dx, dy)
}

OLED_Restore(*) {                  ; OnExit handler — leave bars at their true home
    OLED_PlaceBars(0, 0)
}

OLED_PlaceBars(dx, dy) {
    for hwnd in WinGetList("ahk_exe yasb.exe") {
        if !DllCall("IsWindowVisible", "Ptr", hwnd)   ; hidden (fullscreen) -> skip
            continue
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w < 1000 || h > 60)                        ; bars are full-width & ~30px; skip menus/cards/tray
            continue
        m := OLED_MonitorAt(x + w // 2, y)             ; monitor under the bar's top-center
        MonitorGet(m, &mL, &mT)                         ; monitor bounds top-left (windows_app_bar:false -> y = top)
        WinMove(mL + dx, mT + dy, , , "ahk_id " hwnd)   ; Width/Height omitted -> size unchanged
    }
}

OLED_MonitorAt(px, py) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (px >= L && px < R && py >= T && py < B)
            return A_Index
    }
    return MonitorGetPrimary()
}

OLED_Toggle(*) {                             ; cycle: static -> invisible -> aggressive -> ...
    global oled_presets, oled_idx, oled_mode, oled_Rx, oled_Ry, oled_Tp
    oled_idx := Mod(oled_idx, oled_presets.Length) + 1
    p := oled_presets[oled_idx]
    oled_mode := p.name, oled_Rx := p.Rx, oled_Ry := p.Ry, oled_Tp := p.Tp
    OLED_PlaceBars(0, 0)                      ; snap home now (instant for `static`; drift resumes next tick)
    OSD_Flash("OLED drift · " oled_mode)
}

; --- always-active mode triggers ---
^!+#r::EnterMode("resize")            ; Hyper+r
^!+#`;::EnterMode("service")          ; Hyper+;  (semicolon escaped)
^!+#Escape::ExitMode()                ; panic exit — works from ANY state

; Keyboard work/gaming toggle (Kanata on/off) — mirrors the YASB kanata pill.
^!+#g::Run('pwsh -NoProfile -WindowStyle Hidden -File "' EnvGet("USERPROFILE") '\.config\kanata\kanata-toggle.ps1"', , "Hide")

; ============================================================
; Hyper (^!+#) — focus / act layer
; ============================================================

; Manipulate the current window
^!+#q::Komorebic("close")
^!+#m::Komorebic("minimize")
^!+#t::Komorebic("toggle-float")
^!+#f::Komorebic("toggle-monocle")

; Focus windows
^!+#h::Komorebic("focus left")
^!+#j::Komorebic("focus down")
^!+#k::Komorebic("focus up")
^!+#l::Komorebic("focus right")

; Cycle focus
^!+#[::Komorebic("cycle-focus previous")
^!+#]::Komorebic("cycle-focus next")

; Focus monitors (was Meh+1/2; remapped to free the digit row for workspaces)
^!+#,::Komorebic("focus-monitor 0")
^!+#.::Komorebic("focus-monitor 1")

; Layouts
^!+#x::Komorebic("flip-layout horizontal")
^!+#y::Komorebic("flip-layout vertical")
^!+#c::Komorebic("cycle-layout next")

; Focus workspaces 1-10
^!+#1::Komorebic("focus-workspace 0")
^!+#2::Komorebic("focus-workspace 1")
^!+#3::Komorebic("focus-workspace 2")
^!+#4::Komorebic("focus-workspace 3")
^!+#5::Komorebic("focus-workspace 4")
^!+#6::Komorebic("focus-workspace 5")
^!+#7::Komorebic("focus-workspace 6")
^!+#8::Komorebic("focus-workspace 7")
^!+#9::Komorebic("focus-workspace 8")
^!+#0::Komorebic("focus-workspace 9")

; Workspace back-and-forth (last-focused)
^!+#Tab::Komorebic("focus-last-workspace")

; Suspend these hotkeys
^!+#Home::Suspend

; Guards — these keys are bound on the Meh layer only. AHK lets a Meh hotkey
; (^!+X) fire even when Win is ALSO held, so pressing Hyper on them would bleed
; into the Meh action. Bind them on Hyper as explicit no-ops to prevent that.
^!+#p::return
^!+#n::return
^!+#Enter::return                            ; Hyper+Enter must not bleed into Meh+Enter (promote)

; ============================================================
; Meh (^!+) — move / relocate layer
; ============================================================

; Move windows
^!+h::Komorebic("move left")
^!+j::Komorebic("move down")
^!+k::Komorebic("move up")
^!+l::Komorebic("move right")

; Move across workspaces
^!+p::Komorebic("cycle-move-to-workspace previous")
^!+n::Komorebic("cycle-move-to-workspace next")

; Move to monitor (was Hyper+1/2)
^!+,::Komorebic("move-to-monitor 0")
^!+.::Komorebic("move-to-monitor 1")

; Stack windows
^!+Left::Komorebic("stack left")
^!+Down::Komorebic("stack down")
^!+Up::Komorebic("stack up")
^!+Right::Komorebic("stack right")
^!+`;::Komorebic("unstack")

; Cycle stack
^!+[::Komorebic("cycle-stack previous")
^!+]::Komorebic("cycle-stack next")

; Cycle layout (previous)
^!+c::Komorebic("cycle-layout previous")

; Promote focused window to the main tile
^!+Enter::Komorebic("promote")

; Move windows to workspaces 1-10
^!+1::Komorebic("move-to-workspace 0")
^!+2::Komorebic("move-to-workspace 1")
^!+3::Komorebic("move-to-workspace 2")
^!+4::Komorebic("move-to-workspace 3")
^!+5::Komorebic("move-to-workspace 4")
^!+6::Komorebic("move-to-workspace 5")
^!+7::Komorebic("move-to-workspace 6")
^!+8::Komorebic("move-to-workspace 7")
^!+9::Komorebic("move-to-workspace 8")
^!+0::Komorebic("move-to-workspace 9")

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
f:: {
    Komorebic("toggle-maximize")
    ExitMode()
}
o:: {
    cfg := EnvGet("KOMOREBI_CONFIG_HOME") "\komorebi.json"
    Komorebic('replace-configuration "' cfg '"')
    ExitMode()
}
d:: {
    ExitMode()          ; clear the service badge first
    OLED_Toggle()       ; flip drift preset + flash the new mode
}
Backspace:: {
    RunWait("komorebic.exe stop --masir", , "Hide")   ; take masir down too, else the start below leaks a 2nd masir
    Sleep(1000)
    ; Restart faithfully: mirror the boot shortcut's flags (config + masir).
    ; (--ahk is not a valid start flag on komorebi 0.1.41; the AHK script runs
    ;  independently of komorebi and survives the bounce, so it needs no relaunch.)
    cfg := EnvGet("KOMOREBI_CONFIG_HOME") "\komorebi.json"
    RunWait('komorebic.exe start --config "' cfg '" --masir', , "Hide")
    ExitMode()
}
x:: {
    OSD_Hide()      ; clear the badge before the stack goes down
    RunWait("komorebic.exe stop --ahk --masir", , "Hide")   ; stop komorebi + masir for gaming
    ExitApp()       ; QUIT AutoHotkey (process gone) — anti-cheat needs AHK terminated (ExitApp is the real kill)
}
g:: {
    OSD_Hide()      ; clear the badge before the stack goes down
    ; Full gaming via the profile engine (kanata, komorebi, Docker, VPNs, Steam...).
    ; MUST be Run, not RunWait: the engine kills this AHK partway through (via
    ; wm-toggle) and has to outlive its parent. Come back via `work` / YASB pill.
    Run('pwsh -NoProfile -WindowStyle Hidden -File "' EnvGet("USERPROFILE") '\.config\profile\profile-toggle.ps1" -Gaming', , "Hide")
}
Enter::ExitMode()
Escape::ExitMode()
#HotIf
