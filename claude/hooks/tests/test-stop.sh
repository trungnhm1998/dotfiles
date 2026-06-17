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

# At threshold => systemMessage nudge (shown to the USER, turn ENDS), nudge_level increments
ledger_bump s1 files_written 2     # now 3 >= default 3
out=$(run '{"session_id":"s1"}')
assert_contains "$out" "systemMessage" "nudge emits systemMessage (not additionalContext, which re-wakes the model)"
assert_contains "$out" "/close" "nudge tells the user to run /close"
assert_eq "$(ledger_get s1 '.nudge_level')" "1" "nudge_level incremented"

# Loop-guard regression: stop_hook_active=true must short-circuit BEFORE nudging, even at
# threshold. additionalContext/block on Stop continues the conversation; without this guard
# the hook re-triggers itself until the stop-hook block cap. This is the bug that ran 9x.
out=$(run '{"session_id":"s1","stop_hook_active":true}'); rc=$?
assert_exit "$rc" "0" "stop_hook_active: exits 0"
assert_eq "$out" "" "stop_hook_active: silent (loop guard)"
assert_eq "$(ledger_get s1 '.nudge_level')" "1" "stop_hook_active: nudge_level NOT bumped"

# WIKI_AUTO=0 disables everything
out=$(printf '%s' '{"session_id":"s1"}' | WIKI_AUTO=0 bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "WIKI_AUTO=0 exits 0"
assert_eq "$out" "" "WIKI_AUTO=0 silent"
finish
