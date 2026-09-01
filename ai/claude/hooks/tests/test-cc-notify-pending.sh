#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"

export CCN_HOME="$(mktemp -d)"
# Pre-seed the wezterm icon cache so _cc_wezterm_icon returns instantly (no sips/osascript).
export XDG_CACHE_HOME="$(mktemp -d)"; mkdir -p "$XDG_CACHE_HOME/claude-notify"; : > "$XDG_CACHE_HOME/claude-notify/wezterm.png"

# Stub external commands so cc_notify runs hermetically.
STUB="$(mktemp -d)"
cat > "$STUB/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"#{pane_tty}"*)      echo "/dev/null" ;;
  *"#{session_name}"*)  echo "work" ;;
  *"#{pane_id}"*)       echo "%7" ;;
  *) echo "" ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/sketchybar"
export TN_ARGS="$(mktemp)"   # the terminal-notifier stub records its args here
cat > "$STUB/terminal-notifier" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TN_ARGS"
exit 0
EOF
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

. "$(dirname "$0")/../lib/notify-lib.sh"

# Inside tmux: writes a pending entry keyed by the pane, recording the kind.
export TMUX="x" TMUX_PANE="%7"
cc_notify "Claude Code" "needs you" notification
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "notification" "writes pending kind=notification keyed by pane"
assert_contains "$(cat "$TN_ARGS" 2>/dev/null)" "switch-client -t 'work'" "toast -execute carries the shared ccn_jump_cmd (session from tmux)"
cc_notify "Claude Code" "done" stop
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "stop" "same pane overwrites with kind=stop"

# Default kind is notification when omitted.
rm -f "$CCN_HOME/pending/7"
cc_notify "Claude Code" "hey"
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "notification" "kind defaults to notification"

# Helper missing -> toast falls back to -activate (no broken empty -execute)
export TMUX="x" TMUX_PANE="%7"
( unset -f ccn_jump_cmd; cc_notify "Claude Code" "fallback" notification )
assert_contains "$(cat "$TN_ARGS" 2>/dev/null)" "-activate" "toast falls back to -activate when ccn_jump_cmd is unavailable"

# Outside tmux: no pending entry.
rm -rf "$CCN_HOME/pending"
unset TMUX TMUX_PANE
cc_notify "Claude Code" "hi" notification
test -n "$(ls -A "$CCN_HOME/pending" 2>/dev/null)"; assert_exit "$?" "1" "no pending entry when not in tmux"

finish
