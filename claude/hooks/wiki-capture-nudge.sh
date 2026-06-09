#!/usr/bin/env bash
# Stop-hook nudge: once per session, gently remind Max to file durable knowledge
# into the 05.Wiki via /wiki-capture. Non-blocking (systemMessage only) — it never
# stops the turn, it just surfaces the intent so the habit sticks.
#
# Why once-per-session: the Stop event fires after EVERY assistant turn. Without a
# guard this would print after every single response in every project — pure noise.
# We key a marker file on the session_id so the reminder appears at most once.

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

# No session id → say nothing rather than risk nagging.
[ -z "$sid" ] && exit 0

marker_dir="$HOME/.claude/.wiki-nudge"
mkdir -p "$marker_dir" 2>/dev/null
marker="$marker_dir/$sid"

# Already nudged this session → stay silent.
[ -f "$marker" ] && exit 0

touch "$marker" 2>/dev/null
# Housekeeping: drop markers older than 7 days so the dir doesn't grow forever.
find "$marker_dir" -type f -mtime +7 -delete 2>/dev/null

printf '%s\n' '{"systemMessage":"📥 Wiki check: if this session produced durable knowledge (a convention, gotcha, decision + rationale, or cross-project learning), run /wiki-capture to file it into 05.Wiki."}'
exit 0
