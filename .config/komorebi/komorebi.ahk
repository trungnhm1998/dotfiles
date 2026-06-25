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
^!+#`;::EnterMode("service")          ; Hyper+;  (semicolon escaped)
^!+#Escape::ExitMode()                ; panic exit — works from ANY state

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

; Suspend these hotkeys
^!+#Home::Suspend

; Guards — these keys are bound on the Meh layer only. AHK lets a Meh hotkey
; (^!+X) fire even when Win is ALSO held, so pressing Hyper on them would bleed
; into the Meh action. Bind them on Hyper as explicit no-ops to prevent that.
^!+#p::return
^!+#n::return

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
