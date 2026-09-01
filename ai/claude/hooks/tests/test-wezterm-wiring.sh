#!/usr/bin/env bash
# Static + parse gate for the Claude badge wiring in wezterm.lua. The poller cannot
# be executed outside WezTerm, so we assert structure and that the file still parses.
. "$(dirname "$0")/_harness.sh"

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
WT="$repo_root/.config/wezterm/wezterm.lua"

grep -q 'require("wezterm_claude_alerts")' "$WT"; assert_exit "$?" "0" "wezterm.lua requires the reconcile module"
grep -q "claude_alerts.reconcile(" "$WT"; assert_exit "$?" "0" "wezterm.lua calls reconcile() in update-status"
grep -q "claude_alerts.dir(" "$WT"; assert_exit "$?" "0" "wezterm.lua reads the alert base dir (union-scanned, mux-agnostic)"
grep -q "read_all_subdir_files" "$WT"; assert_exit "$?" "0" "wezterm.lua union-scans per-mux subdirs (no hardcoded socket tag)"
grep -q "user-var-changed" "$WT"; assert_exit "$?" "1" "user-var-changed handler removed"
grep -q 'package.loaded\["tabline.components.tab.claude"\]' "$WT"; assert_exit "$?" "0" "badge component still registered"

# --- Focus-on-click wiring (toast click -> raise the waiting pane) ---
grep -q 'require("wezterm_claude_focus")' "$WT"; assert_exit "$?" "0" "wezterm.lua requires the focus module"
grep -q "claude_focus.dir("                "$WT"; assert_exit "$?" "0" "wezterm.lua reads the focus base dir (union-scanned)"
grep -q "claude_focus.pending("           "$WT"; assert_exit "$?" "0" "wezterm.lua calls focus pending() in update-status"
grep -q ':focus()'                        "$WT"; assert_exit "$?" "0" "wezterm.lua raises the OS window via window:focus()"

if command -v lua >/dev/null 2>&1; then
  WT_PATH="$WT" lua -e "assert(loadfile(os.getenv('WT_PATH')))"
  assert_exit "$?" "0" "wezterm.lua parses (loadfile)"
else
  echo "  SKIP: lua not installed (wezterm.lua parse check)"
fi
finish
