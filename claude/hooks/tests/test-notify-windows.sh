#!/usr/bin/env bash
# Windows-branch behaviour of notify-lib.sh: the fix (no focus-steal, no hardcoded
# path) and the badge OSC emit. Hermetic: stubs uname/powershell.exe, captures the
# OSC via CC_TTY.
. "$(dirname "$0")/_harness.sh"

LIB="$(dirname "$0")/../lib/notify-lib.sh"
PS1="$(dirname "$0")/../bin/claude-notify.ps1"

# --- Part 1 fix: vendored notifier exists and never focuses a pane ---
test -f "$PS1"; assert_exit "$?" "0" "vendored claude-notify.ps1 exists in repo"
grep -qi 'activate-pane' "$PS1"; assert_exit "$?" "1" "vendored notifier contains no activate-pane"
grep -qiE 'c:\\\\tools|/c/tools' "$LIB"; assert_exit "$?" "1" "notify-lib.sh has no hardcoded C:\\Tools path"
grep -q 'BASH_SOURCE' "$LIB"; assert_exit "$?" "0" "notify-lib.sh resolves notifier relative to itself"

# --- Part 2 badge: Windows branch emits the claude_status user-var OSC ---
STUB="$(mktemp -d)"
cat > "$STUB/uname" <<'EOF'
#!/usr/bin/env bash
echo "MINGW64_NT-10.0-26200"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/powershell.exe"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

export CC_TTY="$(mktemp)"
unset TMUX TMUX_PANE            # exercise only the Windows toast/OSC path
. "$LIB"

cc_notify "Claude Code" "needs you" notification
# base64("notification") = bm90aWZpY2F0aW9u
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=bm90aWZpY2F0aW9u" "emits base64('notification') OSC"

: > "$CC_TTY"
cc_notify "Claude Code" "done" stop
# base64("stop") = c3RvcA==
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=c3RvcA==" "emits base64('stop') OSC"

: > "$CC_TTY"
cc_notify "Claude Code" "hi"   # kind omitted -> defaults to notification
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=bm90aWZpY2F0aW9u" "kind defaults to notification in OSC"

finish
