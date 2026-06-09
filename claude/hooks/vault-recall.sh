#!/usr/bin/env bash
# UserPromptSubmit hook — RAG-lite vault recall.
# When Max's prompt reads like a recall question, search his Obsidian vault and
# inject candidate note titles (+ match counts) so Claude consults what Max
# already knows BEFORE answering. Titles only, no content snippets, and
# sensitive-looking files are excluded — per the vault's secret-safety rule.

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$prompt" ] && exit 0

# --- Gate: only fire when the prompt reads like a recall question ---
shopt -s nocasematch
recall_re='(what|how) (do|did|have|can) i|did i (note|writ|sav|captur|do|try|decid)|my (preference|convention|note|setup|decision|approach|workflow|style)|last time|previously|earlier|we (decided|discussed|agreed|talked)|i (decided|noted|prefer|usually|always)|do i have|have i (noted|done|tried|decided)|what.?s my|remember (when|that|how|my)|how i (did|do|usually)|in (the|my) (vault|wiki|notes)|my notes? (on|about)'
[[ "$prompt" =~ $recall_re ]] || { shopt -u nocasematch; exit 0; }
shopt -u nocasematch

source "$(dirname "${BASH_SOURCE[0]}")/lib/obsidian-vault.sh" 2>/dev/null || exit 0
vault="$(resolve_obsidian_vault)" || exit 0
[ -d "$vault" ] || exit 0
cd "$vault" 2>/dev/null || exit 0

# --- Extract salient search terms (>=4 chars, drop common/recall words) ---
stop='what|when|where|which|that|this|with|have|from|your|note|notes|noted|will|would|could|should|been|does|about|know|knew|last|time|times|previously|earlier|before|remember|decided|discuss|discussed|agreed|prefer|preference|convention|setup|decision|approach|workflow|usually|always|tried|done|vault|wiki|notes|thing|things|something|anything|using|used'
terms=$(printf '%s' "$prompt" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -cs 'a-z0-9' '\n' \
  | awk 'length>=4' \
  | grep -Evx "$stop" \
  | sort -u \
  | head -8)
[ -z "$terms" ] && exit 0

pattern=$(printf '%s' "$terms" | paste -sd '|' -)

# --- Find matching notes, drop sensitive-looking files, rank by count ---
mapfile -t rows < <(rg -i -c -e "$pattern" \
    --glob '*.md' \
    --glob '!**/_attachments/**' \
    --glob '!**/.git/**' \
    --glob '!**/.obsidian/**' \
    . 2>/dev/null \
  | grep -Eiv '(secret|credential|recover|passwd|password|2fa|token|api.?key|private.?key|/hr/|hr-|payslip|salary|\bssn\b)' \
  | sort -t: -k2 -rn)
[ ${#rows[@]} -eq 0 ] && exit 0

# Two tiers: notes whose TITLE matches a term (strong signal) rank above notes
# that merely mention the terms in a long body (weak signal, term-frequency noise).
title_list=""
body_list=""
shopt -s nocasematch
for row in "${rows[@]}"; do
  [ -z "$row" ] && continue
  count=${row##*:}
  file=${row%:*}
  rel=${file#./}
  base=${rel##*/}
  entry="- ${rel} (${count} matches)"$'\n'
  if [[ "$base" =~ ($pattern) ]]; then
    title_list="${title_list}${entry}"
  else
    body_list="${body_list}${entry}"
  fi
done
shopt -u nocasematch

list=$(printf '%s%s' "$title_list" "$body_list" | head -8)
[ -z "$list" ] && exit 0

ctx="🔎 Vault recall — Max's prompt looks like a recall question, so I searched his Obsidian vault for terms: ${pattern//|/, }. Candidate notes below — these are LEADS, not the answer. Open the relevant ones with the Read tool and follow their [[links]] before responding from memory:
${list}"

jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0
