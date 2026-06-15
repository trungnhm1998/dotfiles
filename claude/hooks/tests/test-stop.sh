#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/session-ledger-lib.sh"
new_ledger_dir
HOOK="$(dirname "$0")/../session-capture-stop.sh"
run(){ printf '%s' "$1" | bash "$HOOK"; }

# No ledger for this session => silent exit 0
out=$(run '{"session_id":"none"}'); rc=$?
assert_exit "$rc" "0" "no ledger exits 0"
assert_eq "$out" "" "no ledger no output"

# Below threshold => silent (turns still counted)
ledger_init "s1" "/proj" "proj"; ledger_bump s1 files_written 1
out=$(run '{"session_id":"s1"}')
assert_eq "$out" "" "below threshold: no nudge"
assert_eq "$(ledger_get s1 '.turns')" "1" "turn counted even below threshold"

# At threshold => additionalContext nudge, nudge_level increments
ledger_bump s1 files_written 2     # now 3 >= default 3
out=$(run '{"session_id":"s1"}')
assert_contains "$out" "additionalContext" "nudge emits additionalContext"
assert_contains "$out" "/close" "nudge tells agent to run /close"
assert_eq "$(ledger_get s1 '.nudge_level')" "1" "nudge_level incremented"

# WIKI_AUTO=0 disables everything
out=$(printf '%s' '{"session_id":"s1"}' | WIKI_AUTO=0 bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "WIKI_AUTO=0 exits 0"
assert_eq "$out" "" "WIKI_AUTO=0 silent"
finish
