#!/usr/bin/env bash
# Claude Code "Stop" hook — notify when Claude finishes a turn, but ONLY when you are
# not actively looking at Claude's pane, so you don't get a toast after every response.
#
# Focus rule (macOS): if WezTerm is the frontmost app AND Claude's tmux pane is the
# active pane, you're watching -> stay silent. Otherwise (tabbed to a browser, Unity,
# another pane/window, ...) -> notify. Fails safe: if focus can't be determined, notify.
# Delivery is shared with the Notification hook via lib/notify-lib.sh.

source "$(dirname "${BASH_SOURCE[0]}")/lib/notify-lib.sh" 2>/dev/null || exit 0

cat >/dev/null 2>&1 || true   # drain the (unused) stdin payload

# Suppress when you're actively viewing Claude.
if [ "$(uname -s)" = "Darwin" ] && command -v lsappinfo >/dev/null 2>&1; then
  front="$(lsappinfo info -only name "$(lsappinfo front 2>/dev/null)" 2>/dev/null)"
  case "$front" in
    *[Ww]ez[Tt]erm*)
      if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
        active="$(tmux display-message -p -t "$TMUX_PANE" '#{&&:#{window_active},#{pane_active}}' 2>/dev/null)"
        [ "$active" = "1" ] && exit 0   # WezTerm focused + Claude's pane active -> watching
      else
        exit 0                          # WezTerm focused, no tmux -> assume watching
      fi
      ;;
  esac
fi

cc_notify "Claude Code" "finished — back to you" stop
exit 0
