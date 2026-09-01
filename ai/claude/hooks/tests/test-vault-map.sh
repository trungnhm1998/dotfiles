#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../vault-map.sh"

# --- Fixture vault ---
vault="$(mktemp -d)"; mkdir -p "$vault/05.Wiki"
cat > "$vault/05.Wiki/index.md" << 'EOF'
# Index

*Catalog of every wiki page.*

## 🗺️ Maps
- [[Test Hub]] — hub summary.

## 🧠 Concepts
- [[Alpha Concept]] — SENTINEL_ALPHA body text.
- [[Beta Concept]] — SENTINEL_BETA body text.
EOF

out=$(OBSIDIAN_VAULT="$vault" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "fixture vault exits 0"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1
assert_exit "$?" "0" "emits valid hook JSON"
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')

# --- THE regression test for the headline bug: payload must stay tiny ---
len=${#ctx}
TESTS_RUN=$((TESTS_RUN+1))
if [ "$len" -lt 2048 ]; then _pass "payload under 2048 bytes ($len)"
else _fail "payload under 2048 bytes (got $len)"; fi

# --- Scale is conveyed, catalog is not ---
assert_contains "$ctx" "Maps: 1"     "map count present"
assert_contains "$ctx" "Concepts: 2" "concept count present"
assert_not_contains "$ctx" "[[Alpha Concept]]" "catalog titles NOT shipped"
assert_not_contains "$ctx" "SENTINEL_ALPHA"    "catalog summaries NOT shipped"
assert_not_contains "$ctx" "SENTINEL_BETA"     "catalog summaries NOT shipped (beta)"

# --- Dispatch instruction names the agents exactly ---
assert_contains "$ctx" "vault-librarian" "names the librarian agent"
assert_contains "$ctx" "wiki-scribe"     "names the scribe agent"
assert_contains "$ctx" "$vault"          "names the resolved vault path"

# --- Big index must not grow the payload (the 38KB failure, inverted) ---
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
assert_exit "$rc" "0" "2000-entry index exits 0"
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')
biglen=${#ctx}
TESTS_RUN=$((TESTS_RUN+1))
if [ "$biglen" -lt 2048 ]; then _pass "2000-entry index still under 2048 bytes ($biglen)"
else _fail "2000-entry index still under 2048 bytes (got $biglen)"; fi
assert_contains "$ctx" "Concepts: 2000" "big-index count is accurate"
assert_not_contains "$ctx" "PAD_SUMMARY" "big-index content NOT shipped"

# --- Expected absence: vault exists but no index => silent ---
empty="$(mktemp -d)"
out=$(OBSIDIAN_VAULT="$empty" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "missing index exits 0"
assert_eq "$out" "" "missing index stays silent"

# --- Tripwire: vault + index present but jq broken => warning JSON ---
fakebin="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexit 7\n' > "$fakebin/jq"; chmod +x "$fakebin/jq"
out=$(PATH="$fakebin:$PATH" OBSIDIAN_VAULT="$vault" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "broken jq still exits 0"
assert_contains "$out" "vault-map hook failed" "broken pipeline emits warning"

# --- Tripwire: awk broken => ONE warning doc, no concatenated success doc ---
fakebin2="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexit 3\n' > "$fakebin2/awk"; chmod +x "$fakebin2/awk"
out=$(PATH="$fakebin2:$PATH" OBSIDIAN_VAULT="$vault" bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "broken awk still exits 0"
assert_contains "$out" "vault-map hook failed" "broken awk emits warning"
assert_not_contains "$out" "vault-librarian" "no degraded success JSON precedes the warning"
finish
