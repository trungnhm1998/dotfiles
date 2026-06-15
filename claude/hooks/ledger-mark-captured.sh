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
