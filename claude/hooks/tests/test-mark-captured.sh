#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/session-ledger-lib.sh"
new_ledger_dir
HELPER="$(dirname "$0")/../ledger-mark-captured.sh"

# Arrange: a session with uncaptured work + a pointer from cwd
ledger_init "sX" "/work/proj" "proj"
ledger_bump sX files_written 4
key=$(project_key "/work/proj")
pointer_write "$key" "sX" "proj" true "4 files, 0 commits, 0 PRs"

# Act: run helper with explicit cwd
bash "$HELPER" "/work/proj"; rc=$?
assert_exit "$rc" "0" "helper exits 0"

# Assert: ledger captured + pointer flipped
assert_eq "$(ledger_delta sX files_written)" "0" "delta zero after mark-captured"
assert_eq "$(pointer_get "$key" '.uncaptured')" "false" "pointer flipped to captured"
finish
