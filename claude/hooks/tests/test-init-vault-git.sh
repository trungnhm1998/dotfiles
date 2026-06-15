#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
SCRIPT="$(dirname "$0")/../../../scripts/init-vault-git.sh"

vault="$(mktemp -d)"; mkdir -p "$vault/05.Wiki"
out=$(bash "$SCRIPT" "$vault"); rc=$?
assert_exit "$rc" "0" "init exits 0"
test -d "$vault/.git"; assert_exit "$?" "0" ".git created"
test -f "$vault/.gitignore"; assert_exit "$?" "0" ".gitignore created"
( cd "$vault" && git log --oneline >/dev/null 2>&1 ); assert_exit "$?" "0" "has initial commit"
( cd "$vault" && git remote | grep -q . ); assert_exit "$?" "1" "no remote configured"

# Idempotent: second run is a no-op success
out2=$(bash "$SCRIPT" "$vault"); rc2=$?
assert_exit "$rc2" "0" "re-run exits 0"
assert_contains "$out2" "already" "re-run reports already-initialised"
finish
