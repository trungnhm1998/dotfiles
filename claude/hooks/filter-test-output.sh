#!/usr/bin/env bash
# PreToolUse(Bash) hook: forwards to filter-test-output.js, which rewrites
# recognized test/build commands so the model sees failures-only output
# instead of thousands of log lines. Same gated cross-platform pattern as
# agent-flow.sh: find node, else silently no-op so shared settings.json
# works on any machine.

hook_js="$(dirname "${BASH_SOURCE[0]}")/filter-test-output.js"
[ -f "$hook_js" ] || exit 0

node_bin="$(command -v node 2>/dev/null)"
if [ -z "$node_bin" ] && [ -x "/c/Program Files/nodejs/node.exe" ]; then
  node_bin="/c/Program Files/nodejs/node.exe"
fi
[ -n "$node_bin" ] || exit 0

exec "$node_bin" "$hook_js"
