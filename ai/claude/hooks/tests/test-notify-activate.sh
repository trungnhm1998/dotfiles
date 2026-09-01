#!/usr/bin/env bash
# claude-notify.ps1 (emit + activate) and the windowless claude-wez-launch.vbs.
# Static guards need no interpreter; runtime checks are pwsh/cscript-gated.
. "$(dirname "$0")/_harness.sh"

PS1="$(dirname "$0")/../bin/claude-notify.ps1"
VBS="$(dirname "$0")/../bin/claude-wez-launch.vbs"

# --- Static guards: emit mode ---
grep -q 'claude-wez://focus?pane=' "$PS1"; assert_exit "$?" "0" "emit mode builds the claude-wez focus launch URI"
grep -qi 'ActivationType Protocol'  "$PS1"; assert_exit "$?" "0" "emit mode uses protocol activation"
grep -q '\$Activate'                "$PS1"; assert_exit "$?" "0" "ps1 declares the \$Activate handler param + if-block (not just a comment)"
grep -qi 'activate-pane'            "$PS1"; assert_exit "$?" "1" "no WezTerm activate-pane CLI (focus is in-WezTerm)"

# --- Static guards: windowless VBS launcher ---
test -f "$VBS";                       assert_exit "$?" "0" "claude-wez-launch.vbs exists"
grep -q 'claude-notify.ps1'   "$VBS"; assert_exit "$?" "0" "VBS launches claude-notify.ps1 (sibling)"
grep -q '\-Activate'          "$VBS"; assert_exit "$?" "0" "VBS passes -Activate to the ps1"
grep -qi 'WindowStyle Hidden' "$VBS"; assert_exit "$?" "0" "VBS runs pwsh -WindowStyle Hidden"
grep -q ', 0, False'          "$VBS"; assert_exit "$?" "0" "VBS uses windowless Run (0 = hidden, no wait)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "  SKIP: pwsh not installed (activate-mode + dryrun runtime tests)"
  finish; exit 0
fi

PS1_WIN="$(cygpath -w "$PS1" 2>/dev/null || echo "$PS1")"

# --- Activate parses the Windows-normalized 'focus/?' URI -> numeric marker ---
TMPF="$(mktemp -d)"
CC_FOCUS_DIR="$(cygpath -w "$TMPF" 2>/dev/null || echo "$TMPF")" \
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
       -Activate 'claude-wez://focus/?pane=42&mux=gui-sock-77' >/dev/null 2>&1
body="$(cat "$TMPF/gui-sock-77/42" 2>/dev/null)"
printf '%s' "$body" | grep -qE '^[0-9]+$'
assert_exit "$?" "0" "activate parses normalized 'focus/?' URI -> numeric marker at <focus>/gui-sock-77/42 (got '$body')"

# --- Missing pane/mux -> no marker ---
TMPF2="$(mktemp -d)"
CC_FOCUS_DIR="$(cygpath -w "$TMPF2" 2>/dev/null || echo "$TMPF2")" \
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
       -Activate 'claude-wez://focus/?pane=' >/dev/null 2>&1
assert_eq "$(find "$TMPF2" -type f | head -1)" "" "no marker written when URI lacks pane/mux"

# --- Path-traversal URIs are rejected (validation before write); nested dir makes an escape detectable ---
ROOT3="$(mktemp -d)"
CC_FOCUS_DIR="$(cygpath -w "$ROOT3/focus" 2>/dev/null || echo "$ROOT3/focus")" \
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
       -Activate 'claude-wez://focus/?pane=..%5C..%5C..%5Cevil&mux=gui-sock-77' >/dev/null 2>&1
assert_eq "$(find "$ROOT3" -type f | head -1)" "" "traversal in pane is rejected — nothing written under root"
ROOT4="$(mktemp -d)"
CC_FOCUS_DIR="$(cygpath -w "$ROOT4/focus" 2>/dev/null || echo "$ROOT4/focus")" \
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
       -Activate 'claude-wez://focus/?pane=42&mux=..' >/dev/null 2>&1
assert_eq "$(find "$ROOT4" -type f | head -1)" "" "traversal in mux ('..') is rejected — nothing written under root"

# --- VBS builds the correct hidden pwsh command with the URI intact (dryrun seam, no pwsh spawn) ---
if command -v cscript >/dev/null 2>&1; then
  VBS_WIN="$(cygpath -w "$VBS" 2>/dev/null || echo "$VBS")"
  out="$(CC_WEZ_DRYRUN=1 cscript //nologo "$VBS_WIN" 'claude-wez://focus/?pane=42&mux=gui-sock-77' 2>/dev/null)"
  case "$out" in
    *'-WindowStyle Hidden'*'-Activate "claude-wez://focus/?pane=42&mux=gui-sock-77"'*) ok=0 ;;
    *) ok=1 ;;
  esac
  assert_exit "$ok" "0" "VBS builds a hidden pwsh -Activate command with the URI intact"
else
  echo "  SKIP: cscript not installed (VBS dryrun quoting test)"
fi

finish
