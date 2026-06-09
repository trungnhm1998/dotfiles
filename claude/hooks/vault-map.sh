#!/usr/bin/env bash
# SessionStart hook — inject the 05.Wiki catalog so Claude begins each session
# knowing what durable knowledge exists in Max's vault. You can't reach for what
# you don't know is there; this is the "map".

index="C:/ObsidianVaults/05.Wiki/index.md"
[ -f "$index" ] || exit 0

content=$(cat "$index")
directive="Max's durable knowledge lives in his Obsidian vault at C:\\ObsidianVaults — hand-curated PARA notes plus the agent-owned LLM wiki at 05.Wiki. The current 05.Wiki catalog is below. When a question touches Max's own knowledge, preferences, past decisions, or cross-project learnings, CONSULT the relevant pages (open them with the Read tool, follow [[links]]) before answering from memory. Capture new durable knowledge with /wiki-capture."

jq -n --arg d "$directive" --arg c "$content" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:($d + "\n\n--- 05.Wiki/index.md ---\n" + $c)}}'
exit 0
