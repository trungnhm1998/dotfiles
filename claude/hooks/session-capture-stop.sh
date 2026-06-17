#!/usr/bin/env bash
# Stop hook: escalating, ledger-driven capture nudge. Replaces wiki-capture-nudge.sh.
# Phase 1 is nudge-only (no blocking); WIKI_AUTORUN block is Phase 2.
[ "${WIKI_AUTO:-1}" = "0" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/session-ledger-lib.sh" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

# Loop guard. On Stop, additionalContext/decision:block CONTINUES the conversation
# (re-wakes the model), so an unguarded Stop hook re-triggers itself on every forced
# continuation until the stop-hook block cap trips. When we are already inside such a
# continuation, stop_hook_active is true -> let the turn end. Required if Phase 2 ever
# re-enables a blocking decision; harmless for the systemMessage path below.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

f="$(ledger_path "$sid")"
[ -f "$f" ] || exit 0           # no tracked work this session

# Count the turn.
tmp=$(mktemp); jq '.turns = (.turns + 1)' "$f" > "$tmp" && mv "$tmp" "$f"

ledger_meaningful "$sid" || exit 0
level=$(ledger_bump_nudge "$sid")
fw=$(ledger_delta "$sid" files_written); fw=${fw:-0}
fe=$(ledger_delta "$sid" files_edited);  fe=${fe:-0}
gc=$(ledger_delta "$sid" git_commits);   gc=${gc:-0}
files=$((fw + fe))
case "$level" in
  1) tone="📥 Heads up:";;
  2) tone="📥 Reminder —";;
  *) tone="📥 Don't lose this —";;
esac
msg="$tone $files uncaptured file change(s) and $gc commit(s) since the last capture. Run /close to file durable knowledge into 05.Wiki and refresh .planning/continuity.md before wrapping up."
# systemMessage shows the reminder to the USER and lets the turn END. We deliberately do
# NOT use hookSpecificOutput.additionalContext here: on Stop that re-wakes the model, and
# since the standing rule is "never auto-run /close", that just yields dead-air turns (and,
# unguarded, the infinite Stop->nudge->Stop loop this hook used to cause).
jq -n --arg m "$msg" '{systemMessage:$m, suppressOutput:true}'
exit 0
