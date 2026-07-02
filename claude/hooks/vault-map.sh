#!/usr/bin/env bash
# SessionStart hook — inject a SLIM map of the 05.Wiki catalog so Claude begins
# each session knowing what durable knowledge exists in Max's vault. You can't
# reach for what you don't know is there; this is the "map".
#
# Slim = index.md header + the Maps section verbatim (routing hubs), every other
# entry reduced to its [[title]]. Full one-line summaries stay in 05.Wiki/index.md,
# one Read away. Content is STREAMED to jq (-Rs, stdin) — never argv, which
# silently broke at the ~32KB MSYS limit once index.md outgrew it.
set -o pipefail

# Resolve this machine's vault root (see lib/obsidian-vault.sh).
source "$(dirname "${BASH_SOURCE[0]}")/lib/obsidian-vault.sh" 2>/dev/null || exit 0
vault="$(resolve_obsidian_vault)" || exit 0   # no vault here: expected, stay silent

index="$vault/05.Wiki/index.md"
[ -f "$index" ] || exit 0                     # no index yet: expected, stay silent

directive="Max's durable knowledge lives in his Obsidian vault at $vault — hand-curated PARA notes plus the agent-owned LLM wiki at 05.Wiki. The slim catalog below lists every wiki page by title (Maps keep their summaries); full one-line summaries live in 05.Wiki/index.md. When a question touches Max's own knowledge, preferences, past decisions, or cross-project learnings, CONSULT the relevant pages (open them with the Read tool, follow [[links]]) before answering from memory. Capture new durable knowledge with /wiki-capture."

# Slim derivation: keep the header block and the "## 🗺️ Maps" section whole; in
# every other section reduce "- [[Title]] — summary" to "- [[Title]]".
if out="$(awk '
    /^## / { maps = ($0 ~ / Maps$/) }
    /^- /  { if (!maps) sub(/ — .*$/, "") }
           { print }
  ' "$index" \
  | jq -Rs --arg d "$directive" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:($d + "\n\n--- 05.Wiki slim map (full summaries: 05.Wiki/index.md) ---\n" + .)}}')"
then
  printf '%s\n' "$out"
else
  # Vault + index EXIST but injection broke — surface it. This hook once died
  # silently for weeks (argv limit); expected-absence stays silent, breakage must
  # not. Static printf: jq itself may be the broken part.
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"⚠ vault-map hook failed (vault found, injection pipeline broke). Run: bash ~/.claude/hooks/vault-map.sh to debug."}}'
fi
exit 0
