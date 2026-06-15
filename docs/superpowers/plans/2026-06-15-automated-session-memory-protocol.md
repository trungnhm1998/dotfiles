# Automated Close-Session Memory Protocol — Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make durable-knowledge + continuity capture happen reliably at session boundaries by giving dumb shell hooks a deterministic per-session "ledger" that knows when meaningful work is uncaptured, and an LLM `/close` engine that writes the two channels.

**Architecture:** A sourced bash lib (`session-ledger-lib.sh`) maintains a per-session JSON ledger (counts of files/commits/PRs) plus a per-project pointer. A `PostToolUse` hook increments the ledger; a `Stop` hook reads it and injects an escalating nudge when uncaptured work crosses a threshold; a `SessionStart` hook injects the project's continuity doc. The `/close` command + `close-session` skill distil the session into `05.Wiki` (git-committed) and `.planning/continuity.md`, then mark the ledger captured.

**Tech Stack:** Bash (Git-Bash on Windows, sh on macOS/Linux), `jq`, `git`, Claude Code hooks (`PostToolUse`, `Stop`, `SessionStart`), Claude Code commands + skills (Markdown prompt files).

**Spec:** `docs/superpowers/specs/2026-06-15-automated-session-memory-protocol-design.md`

**Phase 1 boundary (this plan):** ledger lib + `session-ledger.sh` + `session-capture-stop.sh` (replaces `wiki-capture-nudge.sh`, nudge-only) + `ledger-mark-captured.sh` + `continuity-readback.sh` (read-back only) + `init-vault-git.sh` + `close-session` skill + `/close` + settings wiring + docs. **Out of scope (Phase 2/3):** `PreCompact` force, fallback reconcile directive, `WIKI_AUTORUN` block, headless capture. The lib still maintains the pointer (Phase-2 foundation) because it is core ledger bookkeeping.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `claude/hooks/lib/session-ledger-lib.sh` | All ledger + pointer read/write/threshold logic (sourced) | Create |
| `claude/hooks/session-ledger.sh` | `PostToolUse(Write\|Edit\|MultiEdit\|Bash)` — increment signals | Create |
| `claude/hooks/session-capture-stop.sh` | `Stop` — escalating, ledger-driven nudge | Create (replaces `wiki-capture-nudge.sh`) |
| `claude/hooks/ledger-mark-captured.sh` | Mark current project's ledger captured (called by `/close`) | Create |
| `claude/hooks/continuity-readback.sh` | `SessionStart` — inject `.planning/continuity.md` | Create |
| `claude/hooks/wiki-capture-nudge.sh` | superseded | Delete |
| `claude/skills/close-session/SKILL.md` | The capture engine (durable + continuity + mark captured) | Create |
| `claude/commands/close.md` | `/close` entry point invoking the skill | Create |
| `scripts/init-vault-git.sh` | One-time: vault under local git (no remote) | Create |
| `claude/hooks/tests/_harness.sh` | Tiny assert/runner harness | Create |
| `claude/hooks/tests/test-*.sh` | Unit tests per component | Create |
| `claude/settings.json` | Register `PostToolUse` + new `SessionStart`; repoint `Stop` | Modify |
| `CLAUDE.md`, `AGENTS.md` | Document protocol + toggles | Modify |

**Lib API (locked — used consistently by all tasks):**

```
ledger_dir                                  # echo dir (honors $CLAUDE_LEDGER_DIR)
project_key <cwd>                            # echo deterministic key (cksum)
ledger_path <session_id>                     # echo "<dir>/<sid>.json"
now_iso                                      # echo UTC timestamp
ledger_init <session_id> <cwd> <project>     # write skeleton if absent
ledger_bump <session_id> <field> [n=1]       # signals.<field> += n
ledger_get <session_id> <jq-path>            # echo raw value ("" if absent)
ledger_delta <session_id> <field>            # signals.<field> - signals_at_capture.<field>
ledger_meaningful <session_id>               # return 0 if delta >= threshold else 1
ledger_bump_nudge <session_id>               # nudge_level += 1; echo new level
ledger_mark_captured <session_id>            # snapshot signals; reset nudge/precompact; stamp time
pointer_write <key> <sid> <project> <bool-uncaptured> <summary>
pointer_get <key> <jq-path>                  # echo value ("" if absent)
```

---

## Task 1: Test harness

**Files:**
- Create: `claude/hooks/tests/_harness.sh`
- Create: `claude/hooks/tests/test-harness-selftest.sh`
- Create: `claude/hooks/tests/run-tests.sh`

- [ ] **Step 1: Write the harness**

`claude/hooks/tests/_harness.sh`:
```bash
#!/usr/bin/env bash
# Minimal test harness for the session-memory hooks. Source this in test files.
TESTS_RUN=0; TESTS_FAILED=0
_pass(){ echo "  PASS: $1"; }
_fail(){ echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }
assert_eq(){ TESTS_RUN=$((TESTS_RUN+1)); if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected '$2', got '$1')"; fi; }
assert_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$1" in *"$2"*) _pass "$3";; *) _fail "$3 (missing '$2' in output)";; esac; }
assert_exit(){ TESTS_RUN=$((TESTS_RUN+1)); if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (exit expected '$2', got '$1')"; fi; }
finish(){ echo "--- $TESTS_RUN run, $TESTS_FAILED failed ---"; [ "$TESTS_FAILED" -eq 0 ]; }
# Each test file gets a fresh, isolated ledger dir.
new_ledger_dir(){ CLAUDE_LEDGER_DIR="$(mktemp -d)"; export CLAUDE_LEDGER_DIR; }
```

`claude/hooks/tests/run-tests.sh`:
```bash
#!/usr/bin/env bash
# Run every test-*.sh in this directory; non-zero exit if any fail.
cd "$(dirname "$0")" || exit 1
rc=0
for t in test-*.sh; do
  echo "== $t =="
  bash "$t" || rc=1
done
exit "$rc"
```

- [ ] **Step 2: Write a self-test**

`claude/hooks/tests/test-harness-selftest.sh`:
```bash
#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
assert_eq "a" "a" "assert_eq matches"
assert_contains "hello world" "world" "assert_contains finds substring"
assert_exit 0 0 "assert_exit matches"
finish
```

- [ ] **Step 3: Run the self-test — verify it passes**

Run: `bash claude/hooks/tests/test-harness-selftest.sh`
Expected: `3 run, 0 failed`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add claude/hooks/tests/_harness.sh claude/hooks/tests/run-tests.sh claude/hooks/tests/test-harness-selftest.sh
git commit -m "test(hooks): add bash test harness for session-memory hooks"
```

---

## Task 2: Ledger lib — paths, keys, init

**Files:**
- Create: `claude/hooks/lib/session-ledger-lib.sh`
- Create: `claude/hooks/tests/test-ledger-lib.sh`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-ledger-lib.sh`:
```bash
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
finish
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: FAIL — `session-ledger-lib.sh` not found / functions undefined.

- [ ] **Step 3: Implement the lib skeleton**

`claude/hooks/lib/session-ledger-lib.sh`:
```bash
#!/usr/bin/env bash
# Shared session-ledger logic. SOURCE this, don't execute.
# A ledger is a per-session JSON file under $(ledger_dir). Honors $CLAUDE_LEDGER_DIR
# so tests run against a temp dir. All functions fail open (no-op) on missing files.

ledger_dir(){ printf '%s' "${CLAUDE_LEDGER_DIR:-$HOME/.claude/.session-ledger}"; }
ledger_path(){ printf '%s/%s.json' "$(ledger_dir)" "$1"; }
project_key(){ printf '%s' "$1" | cksum | cut -d' ' -f1; }
now_iso(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

ledger_init(){
  local sid="$1" cwd="$2" proj="$3" f
  f="$(ledger_path "$sid")"
  mkdir -p "$(ledger_dir)" 2>/dev/null
  [ -f "$f" ] && return 0
  jq -n --arg sid "$sid" --arg cwd "$cwd" --arg proj "$proj" --arg t "$(now_iso)" '
    {session_id:$sid, cwd:$cwd, project:$proj, turns:0,
     signals:{files_written:0,files_edited:0,git_commits:0,prs_opened:0},
     signals_at_capture:{files_written:0,files_edited:0,git_commits:0,prs_opened:0},
     nudge_level:0, precompact_blocked:false, last_capture_at:null, started_at:$t}' > "$f"
}

ledger_get(){
  local f; f="$(ledger_path "$1")"
  [ -f "$f" ] || { printf ''; return 0; }
  jq -r "$2 // empty" "$f" 2>/dev/null
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: `... 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/session-ledger-lib.sh claude/hooks/tests/test-ledger-lib.sh
git commit -m "feat(hooks): ledger lib paths, project_key, init"
```

---

## Task 3: Ledger lib — bump, delta

**Files:**
- Modify: `claude/hooks/lib/session-ledger-lib.sh`
- Modify: `claude/hooks/tests/test-ledger-lib.sh`

- [ ] **Step 1: Add failing tests**

Append to `claude/hooks/tests/test-ledger-lib.sh` **before** the final `finish` line:
```bash
# bump increments signals; delta = signals - signals_at_capture
ledger_init "sidB" "/p" "p"
ledger_bump sidB files_written
ledger_bump sidB files_written 2
assert_eq "$(ledger_get sidB '.signals.files_written')" "3" "bump adds (1 then 2 = 3)"
assert_eq "$(ledger_delta sidB files_written)" "3" "delta = 3 with zero capture baseline"
ledger_bump sidB git_commits
assert_eq "$(ledger_delta sidB git_commits)" "1" "delta git_commits = 1"
```

- [ ] **Step 2: Run — verify new asserts fail**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: FAIL on `bump`/`delta` (functions undefined).

- [ ] **Step 3: Implement bump + delta**

Append to `claude/hooks/lib/session-ledger-lib.sh`:
```bash
ledger_bump(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  jq --arg k "$2" --argjson n "${3:-1}" '.signals[$k] = ((.signals[$k] // 0) + $n)' "$f" > "$tmp" && mv "$tmp" "$f"
}

ledger_delta(){
  local f; f="$(ledger_path "$1")"; [ -f "$f" ] || { printf '0'; return 0; }
  jq -r --arg k "$2" '((.signals[$k] // 0) - (.signals_at_capture[$k] // 0))' "$f" 2>/dev/null
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/session-ledger-lib.sh claude/hooks/tests/test-ledger-lib.sh
git commit -m "feat(hooks): ledger bump + delta"
```

---

## Task 4: Ledger lib — meaningful, mark_captured, bump_nudge

**Files:**
- Modify: `claude/hooks/lib/session-ledger-lib.sh`
- Modify: `claude/hooks/tests/test-ledger-lib.sh`

- [ ] **Step 1: Add failing tests**

Append before `finish`:
```bash
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
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: FAIL (functions undefined).

- [ ] **Step 3: Implement**

Append to `claude/hooks/lib/session-ledger-lib.sh`:
```bash
ledger_meaningful(){
  local sid="$1" fw fe gc pr files
  fw="$(ledger_delta "$sid" files_written)"; fe="$(ledger_delta "$sid" files_edited)"
  gc="$(ledger_delta "$sid" git_commits)";   pr="$(ledger_delta "$sid" prs_opened)"
  files=$(( fw + fe ))
  if [ "$files" -ge "${WIKI_THRESHOLD_FILES:-3}" ] || \
     [ "$gc" -ge "${WIKI_THRESHOLD_COMMITS:-1}" ] || \
     [ "$pr" -ge 1 ]; then
    return 0
  fi
  return 1
}

ledger_bump_nudge(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || { printf '0'; return 0; }
  tmp="$(mktemp)"
  jq '.nudge_level = (.nudge_level + 1)' "$f" > "$tmp" && mv "$tmp" "$f"
  jq -r '.nudge_level' "$f"
}

ledger_mark_captured(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  jq --arg t "$(now_iso)" '
    .signals_at_capture = .signals
    | .nudge_level = 0
    | .precompact_blocked = false
    | .last_capture_at = $t' "$f" > "$tmp" && mv "$tmp" "$f"
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/session-ledger-lib.sh claude/hooks/tests/test-ledger-lib.sh
git commit -m "feat(hooks): ledger meaningful/mark_captured/bump_nudge"
```

---

## Task 5: Ledger lib — per-project pointer

**Files:**
- Modify: `claude/hooks/lib/session-ledger-lib.sh`
- Modify: `claude/hooks/tests/test-ledger-lib.sh`

- [ ] **Step 1: Add failing tests**

Append before `finish`:
```bash
# pointer round-trips a self-contained record
key=$(project_key "/home/x/proj")
pointer_write "$key" "sidF" "proj" true "7 files, 2 commits, 1 PRs"
assert_eq "$(pointer_get "$key" '.session_id')" "sidF" "pointer session_id"
assert_eq "$(pointer_get "$key" '.uncaptured')" "true" "pointer uncaptured bool"
assert_eq "$(pointer_get "$key" '.summary')" "7 files, 2 commits, 1 PRs" "pointer summary"
assert_eq "$(pointer_get 999999 '.session_id')" "" "absent pointer returns empty"
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: FAIL (`pointer_write`/`pointer_get` undefined).

- [ ] **Step 3: Implement**

Append to `claude/hooks/lib/session-ledger-lib.sh`:
```bash
pointer_write(){
  local key="$1" sid="$2" proj="$3" unc="$4" sum="$5" d f
  d="$(ledger_dir)/by-project"; mkdir -p "$d" 2>/dev/null
  f="$d/$key.json"
  jq -n --arg sid "$sid" --arg p "$proj" --argjson u "$unc" --arg s "$sum" --arg t "$(now_iso)" \
    '{session_id:$sid, project:$p, uncaptured:$u, summary:$s, updated_at:$t}' > "$f"
}

pointer_get(){
  local f; f="$(ledger_dir)/by-project/$1.json"
  [ -f "$f" ] || { printf ''; return 0; }
  jq -r "$2 // empty" "$f" 2>/dev/null
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-ledger-lib.sh`
Expected: `0 failed`.

- [ ] **Step 5: shellcheck the lib**

Run: `shellcheck claude/hooks/lib/session-ledger-lib.sh`
Expected: no errors (warnings about `$?` in tests are in the test file, not the lib).

- [ ] **Step 6: Commit**

```bash
git add claude/hooks/lib/session-ledger-lib.sh claude/hooks/tests/test-ledger-lib.sh
git commit -m "feat(hooks): ledger per-project pointer"
```

---

## Task 6: PostToolUse hook — `session-ledger.sh`

**Files:**
- Create: `claude/hooks/session-ledger.sh`
- Create: `claude/hooks/tests/test-session-ledger.sh`
- Modify: `claude/settings.json`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-session-ledger.sh`:
```bash
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
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-session-ledger.sh`
Expected: FAIL — hook does not exist.

- [ ] **Step 3: Implement the hook**

`claude/hooks/session-ledger.sh`:
```bash
#!/usr/bin/env bash
# PostToolUse(Write|Edit|MultiEdit|Bash): increment the session ledger. Silent, fail-open.
source "$(dirname "${BASH_SOURCE[0]}")/lib/session-ledger-lib.sh" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
proj=$(basename "$cwd" 2>/dev/null)

ledger_init "$sid" "$cwd" "$proj"

case "$tool" in
  Write)            ledger_bump "$sid" files_written ;;
  Edit|MultiEdit)   ledger_bump "$sid" files_edited ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit' && ledger_bump "$sid" git_commits
    printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+create' && ledger_bump "$sid" prs_opened
    ;;
esac

# Refresh the per-project pointer (Phase-2 fallback foundation).
key=$(project_key "$cwd")
if ledger_meaningful "$sid"; then unc=true; else unc=false; fi
fw=$(ledger_delta "$sid" files_written); fe=$(ledger_delta "$sid" files_edited)
gc=$(ledger_delta "$sid" git_commits);   pr=$(ledger_delta "$sid" prs_opened)
pointer_write "$key" "$sid" "$proj" "$unc" "$((fw + fe)) files, $gc commits, $pr PRs"
exit 0
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-session-ledger.sh`
Expected: `0 failed`.

- [ ] **Step 5: Register in settings.json**

In `claude/settings.json`, add a top-level `PostToolUse` array inside `hooks` (none exists yet). Place it after the `PreToolUse` block:
```json
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/session-ledger.sh",
            "timeout": 5,
            "statusMessage": "session ledger"
          }
        ]
      }
    ],
```

- [ ] **Step 6: Validate settings JSON**

Run: `jq -e '.hooks.PostToolUse[0].matcher' claude/settings.json`
Expected: prints `"Write|Edit|MultiEdit|Bash"`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add claude/hooks/session-ledger.sh claude/hooks/tests/test-session-ledger.sh claude/settings.json
git commit -m "feat(hooks): PostToolUse session ledger + register"
```

---

## Task 7: `ledger-mark-captured.sh` helper (used by /close)

**Files:**
- Create: `claude/hooks/ledger-mark-captured.sh`
- Create: `claude/hooks/tests/test-mark-captured.sh`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-mark-captured.sh`:
```bash
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
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-mark-captured.sh`
Expected: FAIL — helper does not exist.

- [ ] **Step 3: Implement**

`claude/hooks/ledger-mark-captured.sh`:
```bash
#!/usr/bin/env bash
# Mark the current project's session ledger as captured. Called by /close.
# Resolves the session via the per-project pointer (keyed on cwd), so the caller
# does not need to know the session_id. Fail-open.
source "$(dirname "${BASH_SOURCE[0]}")/lib/session-ledger-lib.sh" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cwd="${1:-$PWD}"
key=$(project_key "$cwd")
sid=$(pointer_get "$key" '.session_id')
[ -n "$sid" ] && ledger_mark_captured "$sid"
pointer_write "$key" "${sid:-unknown}" "$(basename "$cwd")" false "captured $(now_iso)"
exit 0
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-mark-captured.sh`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/ledger-mark-captured.sh claude/hooks/tests/test-mark-captured.sh
git commit -m "feat(hooks): ledger-mark-captured helper for /close"
```

---

## Task 8: Stop hook — `session-capture-stop.sh` (replaces nudge)

**Files:**
- Create: `claude/hooks/session-capture-stop.sh`
- Create: `claude/hooks/tests/test-stop.sh`
- Delete: `claude/hooks/wiki-capture-nudge.sh`
- Modify: `claude/settings.json`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-stop.sh`:
```bash
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
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-stop.sh`
Expected: FAIL — hook does not exist.

- [ ] **Step 3: Implement**

`claude/hooks/session-capture-stop.sh`:
```bash
#!/usr/bin/env bash
# Stop hook: escalating, ledger-driven capture nudge. Replaces wiki-capture-nudge.sh.
# Phase 1 is nudge-only (no blocking); WIKI_AUTORUN block is Phase 2.
[ "${WIKI_AUTO:-1}" = "0" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/session-ledger-lib.sh" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
f="$(ledger_path "$sid")"
[ -f "$f" ] || exit 0           # no tracked work this session

# Count the turn.
tmp=$(mktemp); jq '.turns = (.turns + 1)' "$f" > "$tmp" && mv "$tmp" "$f"

ledger_meaningful "$sid" || exit 0
level=$(ledger_bump_nudge "$sid")
fw=$(ledger_delta "$sid" files_written); fe=$(ledger_delta "$sid" files_edited)
gc=$(ledger_delta "$sid" git_commits)
files=$((fw + fe))
case "$level" in
  1) tone="📥 Heads up:";;
  2) tone="📥 Reminder —";;
  *) tone="📥 Don't lose this —";;
esac
msg="$tone $files uncaptured file change(s) and $gc commit(s) since the last capture. Run /close to file durable knowledge into 05.Wiki and refresh .planning/continuity.md before wrapping up."
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$c}}'
exit 0
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-stop.sh`
Expected: `0 failed`.

- [ ] **Step 5: Delete the superseded hook and repoint settings**

Delete the old file:
```bash
git rm claude/hooks/wiki-capture-nudge.sh
```
In `claude/settings.json`, change the `Stop` hook command from `wiki-capture-nudge.sh` to `session-capture-stop.sh`:
```json
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/session-capture-stop.sh",
            "timeout": 5,
            "statusMessage": "wiki capture check"
          }
        ]
      }
    ]
```

- [ ] **Step 6: Validate settings JSON**

Run: `jq -e '.hooks.Stop[0].hooks[0].command' claude/settings.json`
Expected: prints `"bash ~/.claude/hooks/session-capture-stop.sh"`.

- [ ] **Step 7: Commit**

```bash
git add claude/hooks/session-capture-stop.sh claude/hooks/tests/test-stop.sh claude/settings.json
git commit -m "feat(hooks): escalating ledger-driven Stop nudge; retire wiki-capture-nudge"
```

---

## Task 9: SessionStart hook — `continuity-readback.sh`

**Files:**
- Create: `claude/hooks/continuity-readback.sh`
- Create: `claude/hooks/tests/test-continuity-readback.sh`
- Modify: `claude/settings.json`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-continuity-readback.sh`:
```bash
#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../continuity-readback.sh"

proj="$(mktemp -d)"; mkdir -p "$proj/.planning"
printf '# Continuity\n\n## Next steps\n- finish the widget\n' > "$proj/.planning/continuity.md"

# Present => injects content
out=$(printf '%s' "{\"cwd\":\"$proj\"}" | bash "$HOOK")
assert_contains "$out" "additionalContext" "emits additionalContext"
assert_contains "$out" "finish the widget" "includes continuity content"

# Absent => silent exit 0
empty="$(mktemp -d)"
out=$(printf '%s' "{\"cwd\":\"$empty\"}" | bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "no continuity doc exits 0"
assert_eq "$out" "" "no continuity doc no output"

# WIKI_AUTO=0 silent
out=$(printf '%s' "{\"cwd\":\"$proj\"}" | WIKI_AUTO=0 bash "$HOOK")
assert_eq "$out" "" "WIKI_AUTO=0 silent"
finish
```

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-continuity-readback.sh`
Expected: FAIL — hook does not exist.

- [ ] **Step 3: Implement**

`claude/hooks/continuity-readback.sh`:
```bash
#!/usr/bin/env bash
# SessionStart: inject this project's continuity doc so the session resumes with
# decisions made/pending + next steps in hand. Phase 1 = read-back only
# (Phase 2 adds the walk-away fallback reconcile directive).
[ "${WIKI_AUTO:-1}" = "0" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
doc="$cwd/.planning/continuity.md"
[ -f "$doc" ] || exit 0

content=$(cat "$doc")
directive="Resume context — your previous session left this continuity note for THIS project (changes, decisions made/pending, next steps). Read it before starting new work, and refresh it via /close when you finish meaningful work."
jq -n --arg d "$directive" --arg c "$content" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:($d + "\n\n--- .planning/continuity.md ---\n" + $c)}}'
exit 0
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-continuity-readback.sh`
Expected: `0 failed`.

- [ ] **Step 5: Register in settings.json**

In `claude/settings.json`, add a third object to the existing `SessionStart` array (after the `vault-map.sh` block):
```json
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/continuity-readback.sh",
            "timeout": 10,
            "statusMessage": "continuity read-back"
          }
        ]
      }
```

- [ ] **Step 6: Validate settings JSON**

Run: `jq -e '[.hooks.SessionStart[].hooks[0].command] | any(. == "bash ~/.claude/hooks/continuity-readback.sh")' claude/settings.json`
Expected: prints `true`.

- [ ] **Step 7: Commit**

```bash
git add claude/hooks/continuity-readback.sh claude/hooks/tests/test-continuity-readback.sh claude/settings.json
git commit -m "feat(hooks): SessionStart continuity read-back"
```

---

## Task 10: `init-vault-git.sh` (one-time vault git setup)

**Files:**
- Create: `scripts/init-vault-git.sh`
- Create: `claude/hooks/tests/test-init-vault-git.sh`

- [ ] **Step 1: Write the failing test**

`claude/hooks/tests/test-init-vault-git.sh`:
```bash
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
```

> Note: the test relies on a git identity being configured (Max's global `user.name`/`user.email` are set). If running where it is not, the harness should `git config --global` a throwaway identity first.

- [ ] **Step 2: Run — verify it fails**

Run: `bash claude/hooks/tests/test-init-vault-git.sh`
Expected: FAIL — script does not exist.

- [ ] **Step 3: Implement**

`scripts/init-vault-git.sh`:
```bash
#!/usr/bin/env bash
# One-time: put the Obsidian vault under LOCAL git (no remote) so the close-session
# protocol's auto-captures are committed and revertible. Idempotent.
# Usage: init-vault-git.sh [vault_path]   (defaults to resolved Obsidian vault)
set -euo pipefail

vault="${1:-}"
if [ -z "$vault" ]; then
  source "$HOME/.claude/hooks/lib/obsidian-vault.sh" 2>/dev/null || { echo "vault lib not found"; exit 1; }
  vault="$(resolve_obsidian_vault)" || { echo "no Obsidian vault found"; exit 1; }
fi
[ -d "$vault" ] || { echo "vault path does not exist: $vault"; exit 1; }

cd "$vault"
if [ -d .git ]; then
  echo "vault already a git repo: $vault"
  exit 0
fi

git init -q
cat > .gitignore <<'EOF'
# Obsidian local UI state — not knowledge
.obsidian/workspace*
.obsidian/cache
.trash/
# OS cruft
.DS_Store
Thumbs.db
EOF
git add .gitignore
git commit -q -m "chore: initialise vault git (local audit trail, no remote)"
echo "initialised local git in $vault (no remote)"
```

- [ ] **Step 4: Run — verify it passes**

Run: `bash claude/hooks/tests/test-init-vault-git.sh`
Expected: `0 failed`.

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/init-vault-git.sh claude/hooks/session-ledger.sh claude/hooks/session-capture-stop.sh claude/hooks/continuity-readback.sh claude/hooks/ledger-mark-captured.sh`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/init-vault-git.sh claude/hooks/tests/test-init-vault-git.sh
git commit -m "feat(scripts): init-vault-git for local audit trail"
```

---

## Task 11: `close-session` skill + `/close` command

**Files:**
- Create: `claude/skills/close-session/SKILL.md`
- Create: `claude/commands/close.md`

These are LLM prompt artifacts — verified by live invocation (Task 13), not unit tests.

- [ ] **Step 1: Write the skill**

`claude/skills/close-session/SKILL.md`:
````markdown
---
name: close-session
description: Use at the end of a working session (or when /close is run, or when a Stop/PreCompact nudge fires) to capture durable knowledge into 05.Wiki AND refresh the project's .planning/continuity.md, then mark the session ledger captured. The automated close-session protocol.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Close Session — capture engine

You are running the **two-channel close-session protocol**. The vault root for this
machine is in the session-start vault map; if absent, resolve with
`source ~/.claude/hooks/lib/obsidian-vault.sh && resolve_obsidian_vault` (or `$OBSIDIAN_VAULT`).

Capture has TWO channels — keep them separate:
1. **Durable knowledge → `05.Wiki/`** (reusable conventions, gotchas, decisions WITH rationale, tool/API facts).
2. **Continuity → `<project>/.planning/continuity.md`** (this session's changes, decisions made, decisions pending/open, next steps).

## Flow

1. **Read current state first** (prevents duplicates):
   - `05.Wiki/CLAUDE.md` (schema) and `05.Wiki/index.md` (catalog).
   - `<cwd>/.planning/continuity.md` if it exists.

2. **Durable channel** — distil only genuinely reusable knowledge from THIS session into
   atomic ideas. Update existing wiki pages over creating new ones; correct frontmatter,
   dense `[[wikilinks]]`, a `## Sources` section. Flag contradictions with
   `> [!warning] Contradiction` instead of overwriting. Never assert an unverified Unity/C# API.
   Refresh `05.Wiki/index.md` and append a `05.Wiki/log.md` entry tagged **auto** or **manual**.
   If nothing clears the durable bar, say so plainly and write NO wiki page (still do the continuity channel).

3. **Git audit** — in the vault, stage ONLY the paths you wrote (explicit paths, never `git add -A`)
   and commit:
   ```bash
   cd "$VAULT" && git add 05.Wiki/<changed-files> 05.Wiki/index.md 05.Wiki/log.md \
     && git commit -m "wiki(auto): $(date -u +%F) <one-line summary>"
   ```
   If the vault is not a git repo, skip the commit and note it in your report (run scripts/init-vault-git.sh to enable).

4. **Continuity channel** — rewrite `<cwd>/.planning/continuity.md` from this template
   (create `.planning/` if needed):
   ```markdown
   # Continuity — <project>
   _Updated: <YYYY-MM-DD HH:MM> · session <id-or-unknown>_

   ## Changes this session
   - <what changed: files, features, fixes>

   ## Decisions made
   - <decision> — <rationale> [[wiki-page-if-promoted]]

   ## Decisions pending / open
   - <open question or deferred choice>

   ## Next steps
   - <concrete next action>
   ```

5. **Mark the ledger captured** so the nudges reset:
   ```bash
   bash ~/.claude/hooks/ledger-mark-captured.sh "$PWD"
   ```

6. **Report** which wiki pages you created vs updated (one-line why each), confirm the
   continuity doc path, and list any unresolved `[[links]]` as future-page TODOs.

Be decisive and show brief reasoning — Max is here to learn the system, not just collect files.
````

- [ ] **Step 2: Write the command**

`claude/commands/close.md`:
```markdown
---
description: Close the session — capture durable knowledge to 05.Wiki and refresh continuity, then mark the ledger captured
argument-hint: [optional focus, e.g. "the URP batching gotcha"]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
model: inherit
---

Run the **close-session protocol** (the `close-session` skill). Optional focus from the user: $ARGUMENTS
(If empty, scan the whole session for what's worth keeping; if present, prioritise it.)

Execute both channels — durable knowledge → `05.Wiki/` (git-committed), continuity →
`<project>/.planning/continuity.md` — then run `bash ~/.claude/hooks/ledger-mark-captured.sh "$PWD"`
and report what you wrote. Follow the `close-session` skill exactly.
```

- [ ] **Step 3: Sanity-check frontmatter parses**

Run: `head -n 12 claude/skills/close-session/SKILL.md` and `head -n 8 claude/commands/close.md`
Expected: valid YAML frontmatter, `name`/`description`/`allowed-tools` present.

- [ ] **Step 4: Commit**

```bash
git add claude/skills/close-session/SKILL.md claude/commands/close.md
git commit -m "feat(skill): close-session capture engine + /close command"
```

---

## Task 12: Documentation + deploy mapping

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Document the protocol in CLAUDE.md**

Add a section to `CLAUDE.md` (after the Architecture section) describing the close-session protocol: the ledger, the three hooks, `/close`, the two channels, and the toggle table from the spec (`WIKI_AUTO`, `WIKI_AUTORUN`, `WIKI_FALLBACK`, `WIKI_FALLBACK_HEADLESS`, `WIKI_THRESHOLD_FILES`, `WIKI_THRESHOLD_COMMITS`) with their defaults. Note the one-time `scripts/init-vault-git.sh` setup. Link the spec and this plan by path.

- [ ] **Step 2: Mirror the key facts in AGENTS.md**

Add a short "Session memory protocol" subsection to `AGENTS.md` Key File Locations / Important Patterns: the new hook files, `/close`, and that `claude/` symlinks into `~/.claude/` so the hooks are live after deploy.

- [ ] **Step 3: Verify no broken references**

Run: `grep -n "close-session\|session-ledger\|WIKI_AUTO" CLAUDE.md AGENTS.md`
Expected: matches in both files.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "docs: document close-session memory protocol + toggles"
```

---

## Task 13: Live end-to-end verification

**Files:** none (verification only); deploys symlinks so hooks are live.

- [ ] **Step 1: Run the full unit suite**

Run: `bash claude/hooks/tests/run-tests.sh`
Expected: every file reports `0 failed`, overall exit 0.

- [ ] **Step 2: Deploy symlinks (so ~/.claude picks up new hooks/commands/skill)**

Run (Windows, PowerShell, as Administrator): `.\deploy_windows.ps1 -SkipPackages`
Expected: symlinks refreshed; `~/.claude/hooks/session-ledger.sh` etc. resolve.
Verify: `bash -c 'ls ~/.claude/hooks/session-ledger.sh ~/.claude/commands/close.md ~/.claude/skills/close-session/SKILL.md'`

- [ ] **Step 3: Initialise vault git**

Run: `bash scripts/init-vault-git.sh`
Expected: `initialised local git in <vault> (no remote)` (or `already a git repo`).

- [ ] **Step 4: Simulate ledger + nudge against the real ledger dir**

```bash
sid="e2e-$(date +%s)"
printf '%s' "{\"session_id\":\"$sid\",\"cwd\":\"$PWD\",\"tool_name\":\"Write\",\"tool_input\":{}}" | bash ~/.claude/hooks/session-ledger.sh
printf '%s' "{\"session_id\":\"$sid\",\"cwd\":\"$PWD\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m x\"}}" | bash ~/.claude/hooks/session-ledger.sh
printf '%s' "{\"session_id\":\"$sid\"}" | bash ~/.claude/hooks/session-capture-stop.sh
```
Expected: the Stop call prints JSON with `additionalContext` mentioning `/close` (git commit alone crosses the commit threshold).

- [ ] **Step 5: Meta-capture this work via /close**

In the live session, run `/close`. Confirm: it writes/updates at least one `05.Wiki` page about this protocol, creates/updates `<repo>/.planning/continuity.md`, commits the wiki changes (check `cd "$VAULT" && git log --oneline -1`), and that the ledger is marked captured (re-running the Stop simulation from Step 4 with the same `sid` no longer nudges — delta reset).

- [ ] **Step 6: Final commit (if verification produced doc tweaks)**

```bash
git add -A docs/ claude/
git commit -m "chore: verify close-session protocol end-to-end"
```

---

## Self-review checklist (completed by plan author)

- **Spec coverage:** ledger ✓ (T2-5), PostToolUse ✓ (T6), Stop nudge ✓ (T8), `/close` engine ✓ (T11), continuity channel + template ✓ (T11), continuity read-back ✓ (T9), git audit ✓ (T11 commit step + T10 `git init`), toggles `WIKI_AUTO`/thresholds ✓ (used in T4/T8/T9), docs ✓ (T12). **Deferred to Phase 2/3 (documented):** `PreCompact` force, fallback reconcile directive, `WIKI_AUTORUN` block, headless — out of this plan's scope by design.
- **Type/name consistency:** lib API names (`ledger_init`, `ledger_bump`, `ledger_get`, `ledger_delta`, `ledger_meaningful`, `ledger_bump_nudge`, `ledger_mark_captured`, `pointer_write`, `pointer_get`, `project_key`, `ledger_path`, `ledger_dir`, `now_iso`) are used identically in T6-T13.
- **No placeholders:** every code/test step contains complete content.
```
