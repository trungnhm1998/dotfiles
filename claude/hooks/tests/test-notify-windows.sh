#!/usr/bin/env bash
# Windows-branch behaviour of notify-lib.sh: the notifier fix (no focus-steal, no
# hardcoded path) and the pane-keyed tab-badge file write. Hermetic: stubs
# uname/powershell.exe/cygpath; writes alerts into a temp CC_ALERT_DIR.
. "$(dirname "$0")/_harness.sh"

LIB="$(dirname "$0")/../lib/notify-lib.sh"
PS1="$(dirname "$0")/../bin/claude-notify.ps1"

# --- Part 1: vendored notifier exists and never focuses a pane ---
test -f "$PS1"; assert_exit "$?" "0" "vendored claude-notify.ps1 exists in repo"
grep -qi 'activate-pane' "$PS1"; assert_exit "$?" "1" "vendored notifier contains no activate-pane"
grep -qiE 'c:\\\\tools|/c/tools' "$LIB"; assert_exit "$?" "1" "notify-lib.sh has no hardcoded C:\\Tools path"
grep -q 'BASH_SOURCE' "$LIB"; assert_exit "$?" "0" "notify-lib.sh resolves notifier relative to itself"

# --- Part 2: the OSC/tty channel is gone, replaced by the file channel ---
grep -q 'SetUserVar' "$LIB"; assert_exit "$?" "1" "no SetUserVar OSC emit remains"
grep -q '/dev/tty' "$LIB"; assert_exit "$?" "1" "no /dev/tty write remains"

# --- Part 3: Windows branch writes the pane-keyed alert file ---
STUB="$(mktemp -d)"
cat > "$STUB/uname" <<'EOF'
#!/usr/bin/env bash
echo "MINGW64_NT-10.0-26200"
EOF
PSLOG="$(mktemp)"
printf '#!/usr/bin/env bash\nprintf "called\\n" >> "%s"\nexit 0\n' "$PSLOG" > "$STUB/powershell.exe"
printf '#!/usr/bin/env bash\necho "$2"\n' > "$STUB/cygpath"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

export CC_ALERT_DIR="$(mktemp -d)"
export WEZTERM_PANE=42
unset TMUX TMUX_PANE            # exercise only the Windows path
. "$LIB"

cc_notify "Claude Code" "needs you" notification
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "notification" "writes 'notification' to pane 42's alert file"
assert_contains "$(cat "$PSLOG")" "called" "desktop toast notifier still invoked"

cc_notify "Claude Code" "done" stop
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "stop" "stop overwrites the same pane's alert file"

cc_notify "Claude Code" "hi"   # kind omitted -> defaults to notification
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "notification" "kind defaults to notification"

# --- Part 4: no WEZTERM_PANE -> no file written (graceful no-op) ---
rm -f "$CC_ALERT_DIR"/*
unset WEZTERM_PANE
cc_notify "Claude Code" "no pane" notification
assert_eq "$(ls -A "$CC_ALERT_DIR")" "" "no alert file written when WEZTERM_PANE is unset"

finish
