#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
HOOK="$(dirname "$0")/../continuity-readback.sh"

proj="$(mktemp -d)"; mkdir -p "$proj/.planning"
printf '# Continuity\n\n## Next steps\n- finish the widget\n' > "$proj/.planning/continuity.md"

# Present => injects content
out=$(printf '%s' "{\"cwd\":\"$proj\"}" | bash "$HOOK")
assert_contains "$out" "additionalContext" "emits additionalContext"
assert_contains "$out" "finish the widget" "includes continuity content"

# Absent => silent exit 0
empty="$(mktemp -d)"
out=$(printf '%s' "{\"cwd\":\"$empty\"}" | bash "$HOOK"); rc=$?
assert_exit "$rc" "0" "no continuity doc exits 0"
assert_eq "$out" "" "no continuity doc no output"

# WIKI_AUTO=0 silent
out=$(printf '%s' "{\"cwd\":\"$proj\"}" | WIKI_AUTO=0 bash "$HOOK")
assert_eq "$out" "" "WIKI_AUTO=0 silent"
finish
