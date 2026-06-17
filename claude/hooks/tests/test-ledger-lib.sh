#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/session-ledger-lib.sh"
new_ledger_dir

# project_key is deterministic and filesystem-safe
k1=$(project_key "/home/x/proj"); k2=$(project_key "/home/x/proj")
assert_eq "$k1" "$k2" "project_key deterministic"
case "$k1" in *[!0-9]*) assert_eq "nondigit" "digits-only" "project_key is digits";; *) assert_eq "ok" "ok" "project_key is digits";; esac

# ledger_init creates a skeleton with zeroed signals
ledger_init "sidA" "/home/x/proj" "proj"
assert_eq "$(ledger_get sidA '.session_id')" "sidA" "init sets session_id"
assert_eq "$(ledger_get sidA '.signals.files_written')" "0" "init zeroes files_written"
assert_eq "$(ledger_get sidA '.turns')" "0" "init zeroes turns"

# bump increments signals; delta = signals - signals_at_capture
ledger_init "sidB" "/p" "p"
ledger_bump sidB files_written
ledger_bump sidB files_written 2
assert_eq "$(ledger_get sidB '.signals.files_written')" "3" "bump adds (1 then 2 = 3)"
assert_eq "$(ledger_delta sidB files_written)" "3" "delta = 3 with zero capture baseline"
ledger_bump sidB git_commits
assert_eq "$(ledger_delta sidB git_commits)" "1" "delta git_commits = 1"

# meaningful: below threshold = fail(1), at/above = pass(0)
ledger_init "sidC" "/p" "p"
ledger_meaningful sidC; assert_exit "$?" "1" "empty session not meaningful"
ledger_bump sidC files_written 3            # default WIKI_THRESHOLD_FILES=3
ledger_meaningful sidC; assert_exit "$?" "0" "3 files crosses default threshold"

# mark_captured snapshots signals (delta -> 0) and resets nudge
ledger_bump_nudge sidC >/dev/null            # nudge_level -> 1
ledger_mark_captured sidC
assert_eq "$(ledger_delta sidC files_written)" "0" "delta zero after capture"
assert_eq "$(ledger_get sidC '.nudge_level')" "0" "nudge reset after capture"
test -n "$(ledger_get sidC '.last_capture_at')"; assert_exit "$?" "0" "last_capture_at stamped"

# bump_nudge returns incrementing level
ledger_init "sidD" "/p" "p"
assert_eq "$(ledger_bump_nudge sidD)" "1" "first nudge = 1"
assert_eq "$(ledger_bump_nudge sidD)" "2" "second nudge = 2"

# threshold honors env override
ledger_init "sidE" "/p" "p"; ledger_bump sidE files_written 1
WIKI_THRESHOLD_FILES=1 ledger_meaningful sidE; assert_exit "$?" "0" "env threshold=1 makes 1 file meaningful"

# pointer round-trips a self-contained record
key=$(project_key "/home/x/proj")
pointer_write "$key" "sidF" "proj" true "7 files, 2 commits, 1 PRs"
assert_eq "$(pointer_get "$key" '.session_id')" "sidF" "pointer session_id"
assert_eq "$(pointer_get "$key" '.uncaptured')" "true" "pointer uncaptured bool"
assert_eq "$(pointer_get "$key" '.summary')" "7 files, 2 commits, 1 PRs" "pointer summary"
assert_eq "$(pointer_get 999999 '.session_id')" "" "absent pointer returns empty"

# Cross-form project_key: on Windows (cygpath present) D:\x, /d/x, D:/x are the SAME
# directory and MUST hash to one key. Skipped where cygpath is absent (bug can't occur).
if command -v cygpath >/dev/null 2>&1; then
  kbs=$(project_key 'D:\work\proj')
  kmsys=$(project_key '/d/work/proj')
  kmix=$(project_key 'D:/work/proj')
  assert_eq "$kbs" "$kmsys" "project_key: backslash form == msys form"
  assert_eq "$kbs" "$kmix"  "project_key: backslash form == mixed form"
else
  echo "  SKIP: cross-form project_key (no cygpath)"
fi

finish
