#!/usr/bin/env bash
# MSYS_NO_PATHCONV: without this, Git Bash auto-mangles the POSIX mktemp
# paths we pass to jq's --arg (jq here is a native Windows binary) into
# Windows-style paths, making the payload not match what we asserted against.
export MSYS_NO_PATHCONV=1
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../vault-capture.sh"

state_dir="$(mktemp -d)"
export CLAUDE_VAULT_CAPTURE_STATE="$state_dir"

# Build a transcript with N lines; $2="edit" adds a Write tool_use,
# $3="insight" adds an insight marker.
mk_transcript(){
  local n="$1" kind="$2" f; f="$(mktemp)"
  local i=1
  while [ "$i" -le "$n" ]; do printf '{"type":"filler","n":%d}\n' "$i" >> "$f"; i=$((i+1)); done
  case "$kind" in
    edit)    printf '{"type":"tool_use","name":"Write","input":{}}\n' >> "$f";;
    insight) printf '{"type":"text","text":"the root cause was a stale cache"}\n' >> "$f";;
  esac
  printf '%s' "$f"
}

run(){ printf '%s' "$1" | bash "$HOOK"; }
payload(){ jq -nc --arg s "$1" --arg t "$2" --argjson a "$3" \
  '{session_id:$s, transcript_path:$t, stop_hook_active:$a}'; }

# --- Gate 1: stop_hook_active blocks the fire (loop guard) ---
t=$(mk_transcript 100 edit)
out=$(run "$(payload sess-active "$t" true)")
assert_eq "$out" "" "stop_hook_active=true stays silent (loop guard)"

# --- Gate 2: below the line-delta threshold, no fire ---
t=$(mk_transcript 5 edit)
out=$(run "$(payload sess-small "$t" false)")
assert_eq "$out" "" "delta below MIN_DELTA_LINES stays silent"

# --- Gate 3: enough lines but no edit and no insight, no fire ---
t=$(mk_transcript 100 none)
out=$(run "$(payload sess-dull "$t" false)")
assert_eq "$out" "" "no edit and no insight stays silent"

# --- Fire: lines + edit ---
t=$(mk_transcript 100 edit)
out=$(run "$(payload sess-fire1 "$t" false)"); rc=$?
assert_exit "$rc" "0" "firing path exits 0"
assert_contains "$out" "wiki-scribe" "fires and names the scribe agent"
printf '%s' "$out" | jq -e '.decision == "block"' > /dev/null 2>&1
assert_exit "$?" "0" "emits decision:block"
reason=$(printf '%s' "$out" | jq -r '.reason')
len=${#reason}
TESTS_RUN=$((TESTS_RUN+1))
if [ "$len" -lt 400 ]; then _pass "reason under 400 bytes ($len)"
else _fail "reason under 400 bytes (got $len)"; fi
assert_contains "$reason" "$t" "reason carries the transcript path"

# --- Fire: lines + insight marker, no edit ---
t=$(mk_transcript 100 insight)
out=$(run "$(payload sess-fire2 "$t" false)")
assert_contains "$out" "wiki-scribe" "insight marker alone fires"

# --- State written BEFORE the block, and the offset is recorded ---
test -f "$state_dir/sess-fire1"
assert_exit "$?" "0" "state file created on fire"
recorded=$(cut -d' ' -f1 < "$state_dir/sess-fire1")
assert_eq "$recorded" "101" "state records total line count"

# --- Loop safety: an immediate second Stop on unchanged material must not fire.
#     delta is 0 here, so gate 2 is what stops it.
out=$(run "$(payload sess-fire1 "$t" false)")
assert_eq "$out" "" "second Stop on unchanged transcript stays silent (loop safety)"

# --- Gate 4 in isolation: plenty of NEW material, but still inside cooldown.
#     200 lines vs the recorded 101 gives delta=99, well over MIN_DELTA_LINES,
#     so cooldown is the only thing that can block this one.
t2=$(mk_transcript 200 edit)
out=$(run "$(payload sess-fire1 "$t2" false)")
assert_eq "$out" "" "new material inside cooldown stays silent (gate 4 isolated)"

# --- State write failure must fail closed: no block if state can't persist.
#     Force the write to fail by colliding the state path with a directory of
#     the same name, so the `>` redirect can't open it as a file (proven on
#     this machine: a plain shell redirect to a directory path errors "Is a
#     directory" and returns nonzero -- chmod-based read-only tricks are
#     unreliable on Windows/Git Bash, this collision is not).
wf_dir="$(mktemp -d)"
mkdir "$wf_dir/sess-writefail"
t=$(mk_transcript 100 edit)
export CLAUDE_VAULT_CAPTURE_STATE="$wf_dir"
out=$(run "$(payload sess-writefail "$t" false)"); rc=$?
export CLAUDE_VAULT_CAPTURE_STATE="$state_dir"
assert_exit "$rc" "0" "state write failure still exits 0"
assert_eq "$out" "" "state write failure stays silent (fails closed, no block)"

# --- Missing transcript stays silent ---
out=$(run "$(payload sess-nofile /nonexistent/path.jsonl false)"); rc=$?
assert_exit "$rc" "0" "missing transcript exits 0"
assert_eq "$out" "" "missing transcript stays silent"

# --- Malformed input stays silent ---
out=$(printf 'not json' | bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "malformed input exits 0"
assert_eq "$out" "" "malformed input stays silent"
out=$(printf '' | bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "empty input exits 0"
assert_eq "$out" "" "empty input stays silent"
# --- Compaction: transcript shrank below the recorded offset (Claude Code
#     rewrote it shorter). delta would go negative; must be treated as a
#     fresh start, not a permanent kill of capture for the rest of the
#     session.
t=$(mk_transcript 50 edit)
printf '999 0\n' > "$state_dir/sess-compacted"
out=$(run "$(payload sess-compacted "$t" false)"); rc=$?
assert_exit "$rc" "0" "compaction case exits 0"
assert_contains "$out" "wiki-scribe" "fires after transcript shrinks below recorded offset (compaction)"

finish
