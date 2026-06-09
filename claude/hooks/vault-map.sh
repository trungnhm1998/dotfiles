#!/usr/bin/env bash
# SessionStart hook — inject the 05.Wiki catalog so Claude begins each session
# knowing what durable knowledge exists in Max's vault. You can't reach for what
# you don't know is there; this is the "map".

# Resolve this machine's vault root (see lib/obsidian-vault.sh).
source "$(dirname "${BASH_SOURCE[0]}")/lib/obsidian-vault.sh" 2>/dev/null || exit 0
vault="$(resolve_obsidian_vault)" || exit 0

index="$vault/05.Wiki/index.md"
[ -f "$index" ] || exit 0

content=$(cat "$index")
directive="Max's durable knowledge lives in his Obsidian vault at $vault — hand-curated PARA notes plus the agent-owned LLM wiki at 05.Wiki. The current 05.Wiki catalog is below. When a question touches Max's own knowledge, preferences, past decisions, or cross-project learnings, CONSULT the relevant pages (open them with the Read tool, follow [[links]]) before answering from memory. Capture new durable knowledge with /wiki-capture."

jq -n --arg d "$directive" --arg c "$content" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:($d + "\n\n--- 05.Wiki/index.md ---\n" + $c)}}'
exit 0
