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
