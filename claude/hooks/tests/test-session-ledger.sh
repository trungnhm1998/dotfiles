#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/session-ledger-lib.sh"
new_ledger_dir
HOOK="$(dirname "$0")/../session-ledger.sh"

run(){ printf '%s' "$1" | bash "$HOOK"; }

# Write tool bumps files_written
run '{"session_id":"s1","cwd":"/proj","tool_name":"Write","tool_input":{}}'
assert_eq "$(ledger_get s1 '.signals.files_written')" "1" "Write bumps files_written"

# Edit tool bumps files_edited
run '{"session_id":"s1","cwd":"/proj","tool_name":"Edit","tool_input":{}}'
assert_eq "$(ledger_get s1 '.signals.files_edited')" "1" "Edit bumps files_edited"

# Bash with git commit bumps git_commits
run '{"session_id":"s1","cwd":"/proj","tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
assert_eq "$(ledger_get s1 '.signals.git_commits')" "1" "git commit bumps git_commits"

# Bash WITHOUT git does not bump commits
run '{"session_id":"s1","cwd":"/proj","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
assert_eq "$(ledger_get s1 '.signals.git_commits')" "1" "plain bash leaves commits unchanged"

# gh pr create bumps prs_opened
run '{"session_id":"s1","cwd":"/proj","tool_name":"Bash","tool_input":{"command":"gh pr create -t x"}}'
assert_eq "$(ledger_get s1 '.signals.prs_opened')" "1" "gh pr create bumps prs_opened"

# pointer is maintained
key=$(project_key "/proj")
assert_eq "$(pointer_get "$key" '.session_id')" "s1" "pointer tracks session"

# missing session_id => silent no-op, exit 0
out=$(printf '%s' '{"tool_name":"Write"}' | bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "no session_id exits 0"
assert_eq "$out" "" "no session_id produces no output"
finish
