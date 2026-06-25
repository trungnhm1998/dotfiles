# Session-Ledger `project_key` Path Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/close`'s ledger-mark reliably clear the Stop-hook nudge on Windows by hashing one directory to one `project_key` regardless of path form, and stop the marker failing silently.

**Architecture:** Single-point fix in the shared bash lib `project_key()` (canonicalize via `cygpath -m`, raw fallback) so the PostToolUse writer and the `/close` marker agree; plus a fail-open hardening in the marker script. Verified by the existing bash test harness (TDD, RED before GREEN).

**Tech Stack:** Bash (Git Bash/MSYS on Windows), `cygpath`, `jq`, `cksum`. Dotfiles repo `C:\Users\mint\dotfiles`; `~/.claude/hooks` is a directory **symlink** to `claude/hooks` (edits are live, no deploy).

**Spec:** `docs/superpowers/specs/2026-06-17-session-ledger-project-key-path-normalization-design.md`

## Global Constraints

- Repo: `C:\Users\mint\dotfiles`, base branch `master`. Branch before committing (don't commit on `master`).
- `~/.claude/hooks` is a symlink to `dotfiles/claude/hooks` (verified `LinkType=SymbolicLink`) -> editing the source is live; **no `deploy_windows.ps1` run** (it needs admin + runs the full installer).
- TDD: write the test, watch it FAIL, then implement, watch it PASS.
- Tests use the in-repo bash harness: `assert_eq`, `assert_contains`, `assert_exit`, `finish`, `new_ledger_dir` (from `tests/_harness.sh`). Each test file calls `new_ledger_dir` to get an isolated `CLAUDE_LEDGER_DIR`.
- Cross-form path tests are meaningful ONLY where `cygpath` exists (Windows); guard them with `command -v cygpath` and `SKIP` otherwise (the bug cannot occur on a single-convention OS).
- Commits are GATED: stage with `git add`, then STOP and get explicit user approval before `git commit`. No `Co-Authored-By` / AI-attribution trailers (team policy).
- Run commands below assume cwd = `C:\Users\mint\dotfiles` (Git Bash). Paths are forward-slash.

---

## Task 1: Normalize `project_key` (root fix)

**Files:**
- Modify: `claude/hooks/lib/session-ledger-lib.sh:10` (the `project_key` function)
- Test: `claude/hooks/tests/test-ledger-lib.sh` (add cross-form unit test before `finish`)
- Test: `claude/hooks/tests/test-mark-captured.sh` (add cross-form integration test before `finish`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `project_key(path) -> digits` that returns the SAME value for `D:\x`, `/d/x`, and `D:/x` (one directory -> one key). Callers `session-ledger.sh` (writer), `ledger-mark-captured.sh` (marker), and `session-capture-stop.sh` inherit this unchanged-signature behavior.

- [ ] **Step 1: Create the work branch**

Run:
```bash
git -C /c/Users/mint/dotfiles switch -c fix/session-ledger-project-key-path
```
Expected: "Switched to a new branch 'fix/session-ledger-project-key-path'".

- [ ] **Step 2: Add the cross-form unit test to `test-ledger-lib.sh`**

Insert this block immediately BEFORE the final `finish` line (currently line 56):
```bash
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
```

- [ ] **Step 3: Add the cross-form integration test to `test-mark-captured.sh`**

Insert this block immediately BEFORE the final `finish` line (currently line 20). It reproduces the actual bug: writer records the pointer under one path form, the `/close` marker runs with another:
```bash
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
```

- [ ] **Step 4: Run both tests, verify they FAIL (RED)**

Run:
```bash
bash claude/hooks/tests/test-ledger-lib.sh
bash claude/hooks/tests/test-mark-captured.sh
```
Expected: a `FAIL:` line in each, e.g. `FAIL: project_key: backslash form == msys form (expected '423329672', got '4181477202')` and `FAIL: cross-form: marker resolves session + captures (expected '0', got '4')`; each script ends with a non-zero `--- N run, M failed ---` (M >= 1).

- [ ] **Step 5: Implement the fix in `session-ledger-lib.sh`**

Replace the current one-liner (line 10):
```bash
project_key(){ printf '%s' "$1" | cksum | cut -d' ' -f1; }
```
with:
```bash
project_key(){
  local p="$1"
  # Canonicalize Windows path forms (D:\x, /d/x, D:/x -> D:/x) so one directory hashes to
  # one key regardless of which shell produced the cwd. cygpath exists only under Git
  # Bash/MSYS; on mac/linux the raw POSIX cwd is already consistent across callers.
  if command -v cygpath >/dev/null 2>&1; then
    local m; m=$(cygpath -m -- "$p" 2>/dev/null); [ -n "$m" ] && p="$m"
  fi
  printf '%s' "$p" | cksum | cut -d' ' -f1
}
```

- [ ] **Step 6: Run both tests, verify they PASS (GREEN)**

Run:
```bash
bash claude/hooks/tests/test-ledger-lib.sh
bash claude/hooks/tests/test-mark-captured.sh
```
Expected: all `PASS:` lines, each ending `--- N run, 0 failed ---` (exit 0). No `FAIL:`.

- [ ] **Step 7: Stage the changes (commit is gated to Task 3)**

Run:
```bash
git -C /c/Users/mint/dotfiles add \
  claude/hooks/lib/session-ledger-lib.sh \
  claude/hooks/tests/test-ledger-lib.sh \
  claude/hooks/tests/test-mark-captured.sh
git -C /c/Users/mint/dotfiles status --short
```
Expected: the three files staged (`M`). Do NOT commit yet.

---

## Task 2: Harden the marker's fail-open (`ledger-mark-captured.sh`)

**Files:**
- Modify: `claude/hooks/ledger-mark-captured.sh:8-13`
- Test: `claude/hooks/tests/test-mark-captured.sh` (add clean-miss test before `finish`)

**Interfaces:**
- Consumes: `project_key` (Task 1), `pointer_get`, `ledger_mark_captured`, `pointer_write`, `now_iso` (existing).
- Produces: marker behavior on a pointer miss -> writes NO pointer, prints `ledger-mark-captured: no ledger for <cwd> (key <key>); nothing to mark` to stderr, exits 0.

- [ ] **Step 1: Add the clean-miss test to `test-mark-captured.sh`**

Insert this block immediately BEFORE the final `finish` line (after the Task 1 block):
```bash
# Clean miss: marking a project with NO pointer must NOT persist a junk 'unknown' pointer
# and must say so on stderr (the silent no-op is what hid the path-key bug). Platform-agnostic.
misskey=$(project_key "/no/such/proj")
miss_err=$(bash "$HELPER" "/no/such/proj" 2>&1 >/dev/null); rc=$?
assert_exit "$rc" "0" "clean-miss: helper exits 0"
assert_contains "$miss_err" "nothing to mark" "clean-miss: stderr diagnostic emitted"
assert_eq "$(pointer_get "$misskey" '.session_id')" "" "clean-miss: no junk pointer written"
```

- [ ] **Step 2: Run the test, verify it FAILS (RED)**

Run:
```bash
bash claude/hooks/tests/test-mark-captured.sh
```
Expected: the old marker writes an `unknown` pointer and prints nothing to stderr, so two FAILs appear: `FAIL: clean-miss: stderr diagnostic emitted (missing 'nothing to mark' in output)` and `FAIL: clean-miss: no junk pointer written (expected '', got 'unknown')`. Script ends non-zero.

- [ ] **Step 3: Implement the hardening in `ledger-mark-captured.sh`**

Replace lines 8-13 (currently):
```bash
cwd="${1:-$PWD}"
key=$(project_key "$cwd")
sid=$(pointer_get "$key" '.session_id')
[ -n "$sid" ] && ledger_mark_captured "$sid"
pointer_write "$key" "${sid:-unknown}" "$(basename "$cwd")" false "captured $(now_iso)"
exit 0
```
with:
```bash
cwd="${1:-$PWD}"
key=$(project_key "$cwd")
sid=$(pointer_get "$key" '.session_id')
if [ -n "$sid" ]; then
  ledger_mark_captured "$sid"
  pointer_write "$key" "$sid" "$(basename "$cwd")" false "captured $(now_iso)"
else
  # A silent exit 0 here hid a cwd-form/key mismatch bug; say so instead of no-op'ing.
  echo "ledger-mark-captured: no ledger for $cwd (key $key); nothing to mark" >&2
fi
exit 0
```

- [ ] **Step 4: Run the test, verify it PASSES (GREEN)**

Run:
```bash
bash claude/hooks/tests/test-mark-captured.sh
```
Expected: all `PASS:`, ending `--- N run, 0 failed ---` (exit 0).

- [ ] **Step 5: Stage the changes (commit gated to Task 3)**

Run:
```bash
git -C /c/Users/mint/dotfiles add \
  claude/hooks/ledger-mark-captured.sh \
  claude/hooks/tests/test-mark-captured.sh
git -C /c/Users/mint/dotfiles status --short
```
Expected: marker script + test staged. Do NOT commit yet.

---

## Task 3: Full-suite verification + gated commit

**Files:** none modified (verification + commit only).

- [ ] **Step 1: Run the WHOLE hook test suite, verify no regressions**

Run:
```bash
bash claude/hooks/tests/run-tests.sh; echo "suite exit=$?"
```
Expected: every `== test-*.sh ==` section ends `--- N run, 0 failed ---`, and `suite exit=0`. (No deploy step: `~/.claude/hooks` is a symlink to this repo, so the source IS the live copy.)

- [ ] **Step 2: Live sanity - the deployed marker is the fixed file**

Run (proves the symlinked live lib normalizes both forms to one key):
```bash
bash -c 'source ~/.claude/hooks/lib/session-ledger-lib.sh; echo "bs=$(project_key "D:\\x\\y") msys=$(project_key "/x/y" )"'
```
Expected: not required to match (different dirs) - this only confirms the live lib loads without error after the edit. (The authoritative proof is the green cross-form tests in Step 1.)

- [ ] **Step 3: Stage the spec + plan docs**

Run:
```bash
git -C /c/Users/mint/dotfiles add \
  docs/superpowers/specs/2026-06-17-session-ledger-project-key-path-normalization-design.md \
  docs/superpowers/plans/2026-06-17-session-ledger-project-key-path-normalization.md
git -C /c/Users/mint/dotfiles status --short
```
Expected: spec + plan staged alongside the Task 1/2 code + tests.

- [ ] **Step 4: GATED - confirm with the user, then commit**

Proposed message:
```
fix(hooks): normalize project_key across path forms + harden mark-captured

project_key was cksum of the literal cwd string, so the PostToolUse writer
(Windows form D:\..) and the /close marker (Git-Bash $PWD /d/..) computed
different keys -> the marker's pointer lookup missed -> ledger_mark_captured
was skipped and the Stop nudge never cleared. Canonicalize via cygpath -m
(raw fallback off-Windows) so all forms collapse to one key. Also stop the
marker silently no-opping: emit a stderr note on a miss and drop the junk
'unknown' pointer. Adds cygpath-guarded cross-form tests + a clean-miss test.
```
After explicit user approval, run:
```bash
git -C /c/Users/mint/dotfiles commit -m "<message above>"
```
(No deploy needed; the symlink makes the fix live immediately.)

---

## Self-Review (completed)

- **Spec coverage:** project_key normalization (spec 1) -> Task 1; marker hardening (spec 2) -> Task 2; tests (spec 3) -> Tasks 1-2; deploy/verify (spec 4) -> Task 3 (corrected to symlink = no redeploy). Non-goals (Stop/writer logic, migration) untouched.
- **Placeholders:** none - every code edit shows exact before/after; every run step shows the command + expected output (incl. concrete expected FAIL strings/keys).
- **Type/name consistency:** `project_key` signature unchanged across all callers; test helper names (`assert_eq`/`assert_contains`/`assert_exit`/`ledger_init`/`ledger_bump`/`ledger_delta`/`pointer_write`/`pointer_get`) match `_harness.sh` + `session-ledger-lib.sh`; `$HELPER` is defined at the top of `test-mark-captured.sh`; branch name `fix/session-ledger-project-key-path` consistent throughout.
