#!/usr/bin/env bash
# Runs the Lua unit tests for the WezTerm status module (proc_display / is_claude_title / host_of /
# git / adapters / truncate). The .lua test self-locates wezterm_status.lua beside it in
# .config/wezterm, so it takes no module argument (unlike the alerts/focus/badge wrappers).
. "$(dirname "$0")/_harness.sh"

if ! command -v lua >/dev/null 2>&1; then
  echo "  SKIP: lua not installed (wezterm_status unit test)"
  finish; exit 0
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
lua "$repo_root/.config/wezterm/wezterm_status_test.lua"
assert_exit "$?" "0" "wezterm_status.lua unit tests pass"
finish
