' Auto-start WSL + ensure a persistent tmux "main" session at logon (for phone access).
' Runs hidden (0) and does not wait (False). Remove this file to disable.
'
' Install: copy to
'   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\wsl-tmux-autostart.vbs
CreateObject("WScript.Shell").Run "wsl.exe -d Ubuntu-24.04 -u mint -e bash -lc ""tmux has-session -t main 2>/dev/null || tmux new-session -d -s main""", 0, False
