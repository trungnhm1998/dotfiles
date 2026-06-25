#!/usr/bin/env bash
# Runs the Lua unit test for the WezTerm Claude badge component.
. "$(dirname "$0")/_harness.sh"

if ! command -v lua >/dev/null 2>&1; then
  echo "  SKIP: lua not installed (badge component unit test)"
  finish; exit 0
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
module="$repo_root/.config/wezterm/tabline_claude_badge.lua"
lua "$(dirname "$0")/test-tabline-claude-badge.lua" "$module"
assert_exit "$?" "0" "tabline_claude_badge.lua unit tests pass"
finish
