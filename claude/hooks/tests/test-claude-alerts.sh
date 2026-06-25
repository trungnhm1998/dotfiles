#!/usr/bin/env bash
# Runs the Lua unit test for the WezTerm Claude alert reconcile module.
. "$(dirname "$0")/_harness.sh"

if ! command -v lua >/dev/null 2>&1; then
  echo "  SKIP: lua not installed (claude-alerts reconcile unit test)"
  finish; exit 0
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
module="$repo_root/.config/wezterm/wezterm_claude_alerts.lua"
lua "$(dirname "$0")/test-claude-alerts.lua" "$module"
assert_exit "$?" "0" "wezterm_claude_alerts.lua unit tests pass"
finish
