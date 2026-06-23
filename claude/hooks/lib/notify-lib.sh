#!/usr/bin/env bash
# Shared desktop-notification delivery for Claude Code hooks (Notification + Stop).
#
# cc_notify "<title>" "<body>" surfaces a desktop notification:
#   * Inside tmux  -> a raw BEL (lights tmux's status-bar bell glyph, marks the WezTerm
#     tab, and rings the audible bell) AND an OSC 777 'notify' wrapped for tmux
#     passthrough, which makes WezTerm render a desktop toast with the body text.
#     Requires `set -g allow-passthrough on` in tmux and WezTerm holding macOS
#     Notification Center permission.
#   * Otherwise -> the per-OS native notifier: terminal-notifier (macOS),
#     notify-send (Linux), or the machine-local PowerShell notifier (Windows).
#
# One source of truth so the Notification and Stop hooks deliver identically and the
# escape-sequence math lives in exactly one place.

cc_notify() {
  local title="$1" body="$2"
  [ -z "$body" ] && return 0

  # --- Native path: inside tmux, surface through the terminal stack itself. ---
  if [ -n "${TMUX:-}" ]; then
    local tty
    if [ -n "${TMUX_PANE:-}" ]; then
      tty="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)"
    else
      tty="$(tmux display-message -p '#{pane_tty}' 2>/dev/null)"
    fi
    [ -z "$tty" ] && tty="/dev/tty"
    # OSC 777 is ';'-delimited: flatten newlines/semicolons and strip control chars.
    local ct cb
    ct="$(printf '%s' "$title" | tr '\n;' '  ' | tr -d '\000-\037')"
    cb="$(printf '%s' "$body"  | tr '\n;' '  ' | tr -d '\000-\037')"
    # Write cues + toast to the pane tty. The outer `2>/dev/null` wraps the inner
    # redirect so even a failed open (e.g. no usable tty) never leaks an error.
    { {
      printf '\a'                                                        # in-terminal cues
      printf '\033Ptmux;\033\033]777;notify;%s;%s\007\033\\' "$ct" "$cb" # WezTerm toast
    } > "$tty"; } 2>/dev/null
    return 0
  fi

  # --- Fallback: per-OS native notifier (non-tmux contexts). ---
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      local notifier="/c/Tools/claude-notify.ps1"
      if [ -f "$notifier" ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Tools\\claude-notify.ps1" \
          -Title "$title" -Message "$body" -PaneId "${WEZTERM_PANE:-}"
      fi
      ;;
    Darwin)
      if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "$title" -message "$body" -group "claude-code"
      elif command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\""
      fi
      ;;
    *)
      command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$body"
      ;;
  esac
}
