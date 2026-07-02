#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../vault-recall.sh"

# Fixture vault. "kanata" appears: in a title-matching note (1 body hit), in a
# body-only note under a term-named DIRECTORY (3 hits — more than the title note,
# so only correct tier-ranking puts the title note first), and in a
# sensitive-named note that must be filtered out.
vault="$(mktemp -d)"
mkdir -p "$vault/05.Wiki/concepts" "$vault/05.Wiki/kanata" "$vault/05.Wiki/notes"
printf '# Kanata Setup\n\nkanata config for the 60%% keyboard.\n' \
  > "$vault/05.Wiki/concepts/Kanata Setup.md"
printf 'kanata here.\nkanata again.\nkanata thrice.\n' \
  > "$vault/05.Wiki/kanata/Misc.md"
printf 'kanata secrets.\n' \
  > "$vault/05.Wiki/notes/password recovery.md"

run(){ printf '{"prompt":"%s"}' "$1" | OBSIDIAN_VAULT="$vault" bash "$HOOK"; }

# --- Classic recall prompt still fires ---
out=$(run "what did i note about kanata"); rc=$?
assert_exit "$rc" "0" "recall prompt exits 0"
assert_contains "$out" "Kanata Setup.md" "recall prompt returns lead"

# --- NEW gate: past-work phrasing fires ---
out=$(run "I tried to set up kanata on windows")
assert_contains "$out" "Kanata Setup.md" "'I tried to set up' fires the gate"

# --- Non-recall prompt stays silent ---
out=$(run "fix this null ref in Player.cs"); rc=$?
assert_exit "$rc" "0" "non-recall prompt exits 0"
assert_eq "$out" "" "non-recall prompt stays silent"

# --- Tightened gate: forward-looking "we" questions stay silent ---
out=$(run "how do we mock kanata here")
assert_eq "$out" "" "'how do we <forward>' stays silent"
out=$(run "how can we improve performance here")
assert_eq "$out" "" "'how can we <forward>' stays silent"

# --- Extended wh-words: fire only via the first alternation ---
out=$(run "when did we go with kanata")
assert_contains "$out" "Kanata Setup.md" "'when did we' fires via wh extension"
out=$(run "why did we build kanata")
assert_contains "$out" "Kanata Setup.md" "'why did we' fires via wh extension"

# --- Windows path forms normalized; sensitive files excluded ---
out=$(run "what did i note about kanata")
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')
assert_not_contains "$ctx" '\' "no backslashes in injected paths"
assert_not_contains "$ctx" "password recovery" "sensitive-looking note excluded"

# --- Tier ranking: title match outranks fatter body-only match ---
setup_pos=$(printf '%s\n' "$ctx" | grep -n "Kanata Setup.md" | head -1 | cut -d: -f1)
misc_pos=$(printf '%s\n' "$ctx" | grep -n "Misc.md" | head -1 | cut -d: -f1)
TESTS_RUN=$((TESTS_RUN+1))
if [ -n "$setup_pos" ] && [ -n "$misc_pos" ] && [ "$setup_pos" -lt "$misc_pos" ]; then
  _pass "title-tier note ranks above higher-count body note"
else
  _fail "title-tier note ranks above higher-count body note (setup=$setup_pos misc=$misc_pos)"
fi
finish
