#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/notify-store.sh"
export CCN_HOME="$(mktemp -d)"

# pane key sanitization
assert_eq "$(ccn_pane_key '%23')" "23" "pane_key strips %"
assert_eq "$(ccn_pane_key '%7')"  "7"  "pane_key %7 -> 7"

# write + read kind, keyed by pane; same pane overwrites (dedup)
ccn_write_pending "%7" notification
assert_eq "$(ccn_read_kind 7)" "notification" "write/read kind"
ccn_write_pending "%7" stop
assert_eq "$(ccn_read_kind 7)" "stop" "same pane overwrites (dedup)"
assert_eq "$(ccn_count)" "1" "count=1 after dedup"

# second pane; list sorted numerically
ccn_write_pending "%12" notification
assert_eq "$(ccn_count)" "2" "count=2 with two panes"
assert_eq "$(ccn_list_keys | tr '\n' ' ')" "7 12 " "list sorted numerically"

# clear one
ccn_clear "%7"
assert_eq "$(ccn_count)" "1" "clear removes one"
assert_eq "$(ccn_read_kind 7)" "" "cleared entry gone"

# prune keeps only live keys
ccn_write_pending "%7" notification
ccn_prune "%12"
assert_eq "$(ccn_read_kind 7)"  "" "prune drops dead pane 7"
assert_eq "$(ccn_read_kind 12)" "notification" "prune keeps live pane 12"

# prune with NO live args is a safety no-op (never wipe the store on a failed tmux query)
nb="$(ccn_count)"
ccn_prune
assert_eq "$(ccn_count)" "$nb" "prune with no args is a no-op (safety)"

# clear all
ccn_clear_all
assert_eq "$(ccn_count)" "0" "clear_all empties store"

# empty pane id writes nothing
ccn_write_pending "" notification
assert_eq "$(ccn_count)" "0" "empty pane id writes nothing"

# mode get/set/toggle (default collapsed)
assert_eq "$(ccn_mode_get)" "collapsed" "default mode collapsed"
ccn_mode_set expanded
assert_eq "$(ccn_mode_get)" "expanded" "mode set expanded"
ccn_mode_toggle
assert_eq "$(ccn_mode_get)" "collapsed" "toggle back to collapsed"

finish
