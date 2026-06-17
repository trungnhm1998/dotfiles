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

# Cross-form regression (the real bug): the writer keyed the pointer by the Windows form
# (D:\..), /close's marker ran with the MSYS form (/d/..) -> different keys -> miss -> no
# mark. Post-fix both normalize to one key. cygpath-guarded (Windows-only meaningful).
if command -v cygpath >/dev/null 2>&1; then
  ledger_init "sCF" "D:\\cf\\proj" "proj"
  ledger_bump sCF files_written 4
  kw=$(project_key 'D:\cf\proj')                 # writer keyed by the backslash form
  pointer_write "$kw" "sCF" "proj" true "4 files, 0 commits, 0 PRs"
  bash "$HELPER" "/d/cf/proj"                     # marker invoked with the msys form
  assert_eq "$(ledger_delta sCF files_written)" "0" "cross-form: marker resolves session + captures"
else
  echo "  SKIP: cross-form marker regression (no cygpath)"
fi

# Clean miss: marking a project with NO pointer must NOT persist a junk 'unknown' pointer
# and must say so on stderr (the silent no-op is what hid the path-key bug). Platform-agnostic.
misskey=$(project_key "/no/such/proj")
miss_err=$(bash "$HELPER" "/no/such/proj" 2>&1 >/dev/null); rc=$?
assert_exit "$rc" "0" "clean-miss: helper exits 0"
assert_contains "$miss_err" "nothing to mark" "clean-miss: stderr diagnostic emitted"
assert_eq "$(pointer_get "$misskey" '.session_id')" "" "clean-miss: no junk pointer written"

finish
