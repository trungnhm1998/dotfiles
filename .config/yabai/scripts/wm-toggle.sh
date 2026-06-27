#!/usr/bin/env bash
# wm-toggle.sh — flip yabai on/off for gaming, or report its state glyph.
#   (no args)  -> toggle yabai start/stop-service (debounced)
#   --state    -> print the pill glyph for the current state
# Port of .config/komorebi/wm-toggle.ps1. Hammerspoon stays running (see spec §4.9).
set -euo pipefail

# nf-fa-th (work/tiling) U+F00A · nf-fa-gamepad (game/off) U+F11B — mirrors the Windows pill
GLYPH_WORK=$''
GLYPH_GAME=$''

wm_running() { pgrep -x yabai >/dev/null 2>&1 && echo 1 || echo 0; }

# pure: running(1|0) -> the verb to run
wm_decide() { [ "$1" = "1" ] && echo "stop" || echo "start"; }

# pure: running(1|0) -> state glyph
wm_glyph() { [ "$1" = "1" ] && printf '%s' "$GLYPH_WORK" || printf '%s' "$GLYPH_GAME"; }

wm_toggle() {
  local verb; verb="$(wm_decide "$(wm_running)")"
  # debounce double-clicks/double-taps (mirror the PS mutex)
  exec 9>"/tmp/wm-toggle.lock"
  flock -n 9 || exit 0
  yabai "--${verb}-service"
  echo "$(date +%FT%T) -> ${verb}" >> "/tmp/wm-toggle.log"
}

# run nothing when sourced by the test harness
if [ "${WM_TOGGLE_NOEXEC:-0}" != "1" ]; then
  case "${1:-}" in
    --state) wm_glyph "$(wm_running)" ;;
    *)       wm_toggle ;;
  esac
fi
