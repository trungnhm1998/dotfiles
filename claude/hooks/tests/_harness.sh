#!/usr/bin/env bash
# Minimal test harness for the session-memory hooks. Source this in test files.
TESTS_RUN=0; TESTS_FAILED=0
_pass(){ echo "  PASS: $1"; }
_fail(){ echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }
assert_eq(){ TESTS_RUN=$((TESTS_RUN+1)); if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected '$2', got '$1')"; fi; }
assert_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$1" in *"$2"*) _pass "$3";; *) _fail "$3 (missing '$2' in output)";; esac; }
assert_not_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$1" in *"$2"*) _fail "$3 (unexpected '$2' in output)";; *) _pass "$3";; esac; }
assert_exit(){ TESTS_RUN=$((TESTS_RUN+1)); if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (exit expected '$2', got '$1')"; fi; }
finish(){ echo "--- $TESTS_RUN run, $TESTS_FAILED failed ---"; [ "$TESTS_FAILED" -eq 0 ]; }
# Each test file gets a fresh, isolated ledger dir.
new_ledger_dir(){ CLAUDE_LEDGER_DIR="$(mktemp -d)"; export CLAUDE_LEDGER_DIR; }
