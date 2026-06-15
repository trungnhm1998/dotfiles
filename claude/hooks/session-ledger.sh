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
