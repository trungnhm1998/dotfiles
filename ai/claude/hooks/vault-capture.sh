#!/usr/bin/env bash
# Stop hook -- nudge the main agent to capture durable knowledge into 05.Wiki.
#
# CONFIRMED Stop payload keys (Task 1 probe): background_tasks, cwd, effort,
# hook_event_name, last_assistant_message, permission_mode, prompt_id,
# session_crons, session_id, stop_hook_active, transcript_path
#
# Stop hooks inject via {"decision":"block","reason":...}, which FORCES the turn
# to continue. That is the only lever that makes auto-dispatch happen without Max
# typing anything, and it is also why an ungated hook here is an infinite loop.
# Every condition below is load-bearing, not polish.
#
# Calibration: a full working session transcript measured 187 lines, so 40 lines
# is roughly 8-10 turns.

# --- Tunables ---------------------------------------------------------------
MIN_DELTA_LINES=40
# 30 min, not 10: gate 3 is satisfied by essentially any coding turn, so a
# short cooldown fires roughly every 10 minutes of active work -- each fire
# forces a turn continuation plus a scribe dispatch, and "Nothing durable
# this session" is a common, correct scribe outcome. 30 min cuts that churn
# without starving genuinely long sessions.
COOLDOWN_SECONDS=1800
INSIGHT_RE='root cause|turns out|the bug was|decided|gotcha|learned'
# ---------------------------------------------------------------------------

input=$(cat)
[ -z "$input" ] && exit 0

# Loop guard: never re-fire on the Stop our own block caused.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session" ] && exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  transcript=$(find "$HOME/.claude/projects" -name "${session}.jsonl" -type f 2>/dev/null | head -1)
fi
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

state_dir="${CLAUDE_VAULT_CAPTURE_STATE:-$HOME/.claude/state/vault-capture}"
mkdir -p "$state_dir" 2>/dev/null || exit 0
state="$state_dir/$session"

last_line=0; last_time=0
if [ -f "$state" ]; then
  read -r last_line last_time < "$state" 2>/dev/null
  case "$last_line" in ''|*[!0-9]*) last_line=0;; esac
  case "$last_time" in ''|*[!0-9]*) last_time=0;; esac
fi

now=$(date +%s)
total=$(wc -l < "$transcript" 2>/dev/null | tr -d ' ')
case "$total" in ''|*[!0-9]*) exit 0;; esac
delta=$(( total - last_line ))

# A shorter transcript than our recorded offset means compaction rewrote it,
# not that nothing happened. Without this, delta goes negative, gate 2 fails
# forever, and last_line only updates on a fire -- capture dies permanently
# for the rest of the session, right when a long session needs it most.
if [ "$delta" -lt 0 ]; then
  last_line=0
  delta=$total
fi

[ "$delta" -ge "$MIN_DELTA_LINES" ] || exit 0
[ $(( now - last_time )) -ge "$COOLDOWN_SECONDS" ] || exit 0

chunk=$(tail -n "$delta" "$transcript" 2>/dev/null)
edits=$(printf '%s' "$chunk" | grep -Eo '"name":"(Write|Edit)"' 2>/dev/null | wc -l | tr -d ' ')
case "$edits" in ''|*[!0-9]*) edits=0;; esac
if [ "$edits" -eq 0 ] && ! printf '%s' "$chunk" | grep -Eqi "$INSIGHT_RE"; then
  exit 0
fi

# Write state BEFORE emitting the block: a crash mid-capture must not loop.
# If the write itself fails (disk full, permission, read-only fs), fail
# closed -- skip this capture silently rather than emit a block with no
# offset recorded, which would let the next Stop see the same zero cooldown.
# Braces, not a bare redirect: a redirection SETUP failure is reported by the
# shell itself, so a trailing 2>/dev/null on the command never suppresses it.
{ printf '%s %s\n' "$total" "$now" > "$state"; } 2>/dev/null || exit 0

reason="Vault capture: ${delta} new transcript lines since last capture, including ${edits} file edits. Dispatch the wiki-scribe subagent to capture durable knowledge into 05.Wiki (transcript: ${transcript}, from line ${last_line}). Do NOT read the transcript yourself; the scribe reads it in its own context."

jq -n --arg r "$reason" '{decision:"block",reason:$r}'
exit 0
