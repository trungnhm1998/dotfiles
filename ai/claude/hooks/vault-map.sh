#!/usr/bin/env bash
# SessionStart hook — inject a POINTER to the vault wiki, never the catalog.
#
# History: this hook used to awk-slim 05.Wiki/index.md (142KB) and inject the
# result inline. At 38,065 bytes that blew past Claude Code's inline hook-output
# limit; the payload was truncated to a ~2KB preview and persisted to a file, so
# roughly 94% of the catalog never reached the model. Shipping scale plus a
# dispatch instruction costs 630 bytes and works, because vault-librarian reads
# the catalog in its own context window.
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/obsidian-vault.sh" 2>/dev/null || exit 0
vault="$(resolve_obsidian_vault)" || exit 0   # no vault here: expected, stay silent

index="$vault/05.Wiki/index.md"
[ -f "$index" ] || exit 0                     # no index yet: expected, stay silent

# Section counts convey scale in ~40 bytes. "## 🧠 Concepts" -> "Concepts: 333".
if counts="$(awk '
    /^## / { if (h) printf "%s: %d; ", h, n; sub(/^## +/, "", $0); sub(/^[^A-Za-z]+/, "", $0); h = $0; n = 0; next }
    /^- /  { n++ }
    END    { if (h) printf "%s: %d", h, n }
  ' "$index")" && [ -n "$counts" ]; then
  ctx="Max's durable knowledge lives in his Obsidian vault at ${vault} (hand-curated PARA notes plus the agent-owned LLM wiki at 05.Wiki). Wiki scale: ${counts}.
When a prompt asks about Max's own knowledge, preferences, past decisions, or cross-project learnings, dispatch the vault-librarian subagent and wait for its answer before replying; it reads 05.Wiki/index.md and returns a short answer with source paths. Do not grep the vault yourself. Ordinary in-repo coding does not need it.
To record durable knowledge from this session, dispatch the wiki-scribe subagent (or run /wiki-capture)."
  out="$(jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}')" || out=""
else
  out=""
fi

if [ -n "$out" ]; then
  printf '%s\n' "$out"
else
  # Vault + index EXIST but injection broke — surface it. This hook once died
  # silently for weeks; expected-absence stays silent, breakage must not.
  # Static printf: jq itself may be the broken part.
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"WARNING: vault-map hook failed (vault found, injection pipeline broke). Run: bash ~/.claude/hooks/vault-map.sh to debug."}}'
fi
exit 0
