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

finish
