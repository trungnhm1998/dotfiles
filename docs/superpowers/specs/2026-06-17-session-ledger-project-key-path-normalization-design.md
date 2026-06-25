# Session-Ledger `project_key` Path Normalization - Design

**Date:** 2026-06-17
**Repo:** dotfiles (`claude/hooks`)
**Follows:** `2026-06-15-automated-session-memory-protocol-design.md` (bug fix in that system)
**Status:** Approved (brainstorming) - pending implementation plan

## Problem

`/close`'s ledger-mark step **silently no-ops on Windows**, so the Stop-hook capture
nudge never clears even after a real capture (observed live: the nudge re-fired and
escalated to level 3 despite a completed wiki capture + continuity write).

**Root cause.** `project_key()` in `claude/hooks/lib/session-ledger-lib.sh` is
`cksum` of the *literal* cwd string:

```bash
project_key(){ printf '%s' "$1" | cksum | cut -d' ' -f1; }
```

The two callers feed it the same directory in **different path conventions**:

- **Writer** `session-ledger.sh` (PostToolUse) keys the per-project pointer by
  `project_key(cwd)` where `cwd` is the hook payload's Windows form
  `D:\projects\neopets\NeopetsMatchDream_Client`.
- **Marker** `ledger-mark-captured.sh` (run by `/close`) keys by `project_key("$PWD")`
  where Git-Bash `$PWD` is the MSYS form `/d/projects/neopets/NeopetsMatchDream_Client`.

Different strings -> different cksum -> the marker's pointer lookup misses -> `sid` is
empty -> `ledger_mark_captured` is skipped -> `exit 0`. The miss is **silent** and the
script still writes a junk `sid="unknown"` pointer. Meanwhile the Stop hook keys by
`session_id` (not `project_key`), so it keeps reading the same ledger, sees delta > 0,
and re-nudges.

Verified live (cksum of each form):

| cwd form | example | key |
|---|---|---|
| Windows backslash (writer) | `D:\projects\...\NeopetsMatchDream_Client` | 4181477202 |
| MSYS (marker via `$PWD`) | `/d/projects/...\NeopetsMatchDream_Client` | 423329672 |
| Windows forward-slash | `D:/projects/...\NeopetsMatchDream_Client` | 1347436766 |

## Goal

One directory hashes to one `project_key` regardless of which shell/convention produced
the cwd, so writer and marker agree. Plus: the marker must not fail silently.

**Non-goals:** changing the Stop/writer hook logic; migrating existing pointers
(self-heals next session - old pointers orphan harmlessly); any mac/linux behavior change.

## Design

### 1. `project_key` normalization (root fix) - `session-ledger-lib.sh`

Canonicalize via `cygpath -m` (present only under Git-Bash/MSYS) before hashing; raw
string fallback everywhere else.

```bash
project_key(){
  local p="$1"
  # Canonicalize Windows path forms (D:\x, /d/x, D:/x  ->  D:/x) so one directory
  # hashes to one key regardless of which shell produced the cwd. cygpath exists
  # only under Git Bash/MSYS; on mac/linux the raw POSIX cwd is already consistent
  # across callers, so skip it.
  if command -v cygpath >/dev/null 2>&1; then
    local m; m=$(cygpath -m -- "$p" 2>/dev/null); [ -n "$m" ] && p="$m"
  fi
  printf '%s' "$p" | cksum | cut -d' ' -f1
}
```

**Rationale.** `cygpath -m` authoritatively collapses `D:\x`, `/d/x`, and `D:/x` to the
mixed form `D:/x` (verified live: all three -> key 1347436766). It is absent on mac/linux,
where the raw POSIX cwd is already identical across callers, so the fallback is a no-op
there. Chosen over hand-rolled string munging (more code, more Windows edge cases, bash
3.2 vs 4+ uppercase concerns) and over a per-caller band-aid (brittle; leaves the writer
and any future pointer consumer exposed).

**Boundary (documented, harmless).** On Windows, `cygpath -m /Users/x` mis-maps a genuine
POSIX path to the Git install root (`C:/Program Files/Git/Users/x`). This never bites:
real Windows cwds always start with a drive letter, and mac-style paths only occur on a
mac (no `cygpath`, raw fallback). The existing `project_key "/home/x/proj"` determinism
test still passes because the same transform is applied to both sides.

### 2. Marker hardening - `ledger-mark-captured.sh`

Only write the pointer when a `sid` actually resolves (no more junk `unknown` pointer),
and emit a stderr diagnostic on a miss instead of a silent `exit 0`.

```bash
cwd="${1:-$PWD}"
key=$(project_key "$cwd")
sid=$(pointer_get "$key" '.session_id')
if [ -n "$sid" ]; then
  ledger_mark_captured "$sid"
  pointer_write "$key" "$sid" "$(basename "$cwd")" false "captured $(now_iso)"
else
  echo "ledger-mark-captured: no ledger for $cwd (key $key); nothing to mark" >&2
fi
exit 0
```

### 3. Tests (bash harness, TDD - RED before fix, GREEN after)

- `tests/test-ledger-lib.sh`: a `cygpath`-guarded test that the three Windows forms of one
  path yield the **same** `project_key`. Fails on current code (three different cksums),
  passes after the fix. Skipped where `cygpath` is absent (the bug cannot occur there).
- `tests/test-mark-captured.sh`: the regression that would have caught this -
  writer records the pointer via form X, marker invoked with form Y -> assert
  `ledger_delta -> 0` (cygpath-guarded). Plus: a genuine miss (unknown project) writes
  **no** pointer and still exits 0.

### 4. Deploy

`~/.claude/hooks` is a directory **symlink** to `dotfiles/claude/hooks` (created once by
`deploy_windows.ps1`; verified live: `LinkType=SymbolicLink`), so editing the source files is
**immediately live** in `~/.claude` - no redeploy needed, and the test suite (which sources
`../lib/...` from the repo) runs against the file that IS the deployed copy. `deploy_windows.ps1`
requires Administrator and runs the full installer; only run it if the symlink is ever missing.

## Files changed

- `claude/hooks/lib/session-ledger-lib.sh` - `project_key` normalization
- `claude/hooks/ledger-mark-captured.sh` - fail-open hardening
- `claude/hooks/tests/test-ledger-lib.sh` - cross-form `project_key` test
- `claude/hooks/tests/test-mark-captured.sh` - cross-form marker regression + clean-miss test

## Verification

- `bash claude/hooks/tests/run-tests.sh` -> all green, including the two new tests.
- Live end-to-end: invoke the marker with a different path form than the writer used and
  confirm the ledger delta goes to 0 (nudge would clear).

## Out of scope / follow-ups

- Capturing this gotcha into the `Claude Code Hooks` wiki page (happens at next `/close`).
- Commits are gated on explicit user approval. No deploy step needed (`~/.claude/hooks` is a symlink to the repo).
