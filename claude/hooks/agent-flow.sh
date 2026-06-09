#!/usr/bin/env bash
# Cross-platform launcher for the optional agent-flow hook.
#
# agent-flow ships a single hook.js that handles EVERY Claude Code hook event — it
# reads hook_event_name from the JSON payload on stdin and dispatches internally.
# This wrapper finds node + hook.js on the current machine and forwards the payload
# to it. If either is missing it no-ops silently, so the shared settings.json works
# on any machine (including ones without agent-flow installed, like this Mac).

# Locate the hook script: explicit override, else the conventional install path.
hook_js="${AGENT_FLOW_HOOK:-$HOME/.claude/agent-flow/hook.js}"
[ -f "$hook_js" ] || exit 0

# Locate node: PATH first (macOS/Linux/Windows-bash), then the default Windows install.
node_bin="$(command -v node 2>/dev/null)"
if [ -z "$node_bin" ] && [ -x "/c/Program Files/nodejs/node.exe" ]; then
  node_bin="/c/Program Files/nodejs/node.exe"
fi
[ -n "$node_bin" ] || exit 0

# Hand off: stdin payload flows through, hook.js's stdout becomes our stdout.
exec "$node_bin" "$hook_js"
