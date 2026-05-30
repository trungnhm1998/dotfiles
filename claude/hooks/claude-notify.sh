#!/usr/bin/env bash
# Cross-platform Claude Code Notification hook.
# Reads the hook JSON payload on stdin and surfaces .message as a desktop notification.
# Windows: delegates to the machine-local C:\Tools\claude-notify.ps1 (passes the wezterm pane id).
# macOS:   uses osascript if available. Linux: uses notify-send if available. Otherwise no-op.

payload="$(cat)"
message="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
[ -z "$message" ] && exit 0

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    notifier="/c/Tools/claude-notify.ps1"
    if [ -f "$notifier" ]; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Tools\\claude-notify.ps1" \
        -Title "Claude Code" -Message "$message" -PaneId "${WEZTERM_PANE:-}"
    fi
    ;;
  Darwin)
    command -v osascript >/dev/null 2>&1 && \
      osascript -e "display notification \"${message//\"/\\\"}\" with title \"Claude Code\""
    ;;
  *)
    command -v notify-send >/dev/null 2>&1 && notify-send "Claude Code" "$message"
    ;;
esac
exit 0
