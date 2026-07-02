#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../vault-map.sh"

# --- Fixture vault: slim-map derivation cases ---
vault="$(mktemp -d)"; mkdir -p "$vault/05.Wiki"
cat > "$vault/05.Wiki/index.md" << 'EOF'
# Index

*Catalog of every wiki page. Updated on every ingest; read first on every query.*
*Sources: 1 · Concepts: 2 · Entities: 0 · Maps: 1 · Notes: 0 — last updated 2026-07-02*

> Start at [[overview]] · timeline in [[log]].

## 🗺️ Maps
- [[Test Hub]] — hub summary that must survive verbatim.

## 🧠 Concepts
- [[Alpha Concept]] — SENTINEL_SUMMARY_ALPHA body text that must be stripped.
- [[Beta Long Name|Beta Alias]] — SENTINEL_SUMMARY_BETA with an alias link.
EOF

out=$(OBSIDIAN_VAULT="$vault" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "fixture vault exits 0"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1
assert_exit "$?" "0" "emits valid hook JSON"
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')
assert_contains "$ctx" "hub summary that must survive verbatim" "Maps section kept whole"
assert_contains "$ctx" "[[Alpha Concept]]" "concept title kept"
assert_contains "$ctx" "[[Beta Long Name|Beta Alias]]" "alias-form title kept"
assert_not_contains "$ctx" "SENTINEL_SUMMARY_ALPHA" "concept summary stripped"
assert_not_contains "$ctx" "SENTINEL_SUMMARY_BETA" "alias-entry summary stripped"
assert_contains "$ctx" "— last updated 2026-07-02" "header em-dash line untouched (only '- ' entries stripped)"
assert_contains "$ctx" "05.Wiki/index.md" "directive points at the full index"

# --- Big index: content must never ride argv (the original 101KB failure) ---
big="$(mktemp -d)"; mkdir -p "$big/05.Wiki"
{
  printf '# Index\n\n## 🗺️ Maps\n- [[Hub]] — hub line.\n\n## 🧠 Concepts\n'
  i=1
  while [ "$i" -le 2000 ]; do
    printf -- '- [[Concept %04d]] — PAD_SUMMARY %s\n' "$i" \
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    i=$((i+1))
  done
} > "$big/05.Wiki/index.md"
out=$(OBSIDIAN_VAULT="$big" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "200KB index exits 0"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1
assert_exit "$?" "0" "200KB index emits valid JSON (argv immunity)"
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')
assert_contains "$ctx" "[[Concept 1999]]" "big-index titles present"
assert_not_contains "$ctx" "PAD_SUMMARY" "big-index summaries stripped"

# --- Expected absence: vault dir exists but no 05.Wiki/index.md => silent ---
empty="$(mktemp -d)"
out=$(OBSIDIAN_VAULT="$empty" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "missing index exits 0"
assert_eq "$out" "" "missing index stays silent"

# --- Tripwire: vault + index present but pipeline broken => warning JSON ---
fakebin="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexit 7\n' > "$fakebin/jq"; chmod +x "$fakebin/jq"
out=$(PATH="$fakebin:$PATH" OBSIDIAN_VAULT="$vault" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "broken pipeline still exits 0"
assert_contains "$out" "vault-map hook failed" "broken pipeline emits warning"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1
assert_exit "$?" "0" "warning is valid hook JSON"
finish
