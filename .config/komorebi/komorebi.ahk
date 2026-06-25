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

; Resize (was Ctrl+Alt+hjkl; moved to Hyper+arrows)
^!+#Left::Komorebic("resize-edge left increase")
^!+#Down::Komorebic("resize-edge down increase")
^!+#Up::Komorebic("resize-edge up increase")
^!+#Right::Komorebic("resize-edge right increase")

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

; Restart komorebi
^!+#Backspace::{
    RunWait("komorebic.exe stop", , "Hide")
    Sleep(1000)
    RunWait("komorebic.exe start", , "Hide")
}

; Suspend these hotkeys
^!+#Home::Suspend

; Guards — these keys are bound on the Meh layer only. AHK lets a Meh hotkey
; (^!+X) fire even when Win is ALSO held, so pressing Hyper on them would bleed
; into the Meh action. Bind them on Hyper as explicit no-ops to prevent that.
^!+#p::return
^!+#n::return
^!+#r::return
^!+#`;::return

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

; Window manager options
^!+r::Komorebic("retile")
^!+q::Komorebic("toggle-pause")

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
