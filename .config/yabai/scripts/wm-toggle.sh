#!/usr/bin/env bash
# wm-toggle.sh — flip yabai on/off for gaming, or report its state glyph.
#   (no args)  -> toggle yabai start/stop-service (debounced)
#   --state    -> print the pill glyph for the current state
# Port of .config/komorebi/wm-toggle.ps1. Hammerspoon stays running (see spec §4.9).
set -euo pipefail

# nf-fa-th (work/tiling) U+F00A · nf-fa-gamepad (game/off) U+F11B — mirrors the Windows pill
GLYPH_WORK=$(printf '\357\200\212')   # U+F00A nf-fa-th (work/tiling) — UTF-8 EF 80 8A
GLYPH_GAME=$(printf '\357\204\233')   # U+F11B nf-fa-gamepad (game/off) — UTF-8 EF 84 9B

wm_running() { pgrep -x yabai >/dev/null 2>&1 && echo 1 || echo 0; }

# pure: running(1|0) -> the verb to run
wm_decide() { [ "$1" = "1" ] && echo "stop" || echo "start"; }

# pure: running(1|0) -> state glyph
wm_glyph() { [ "$1" = "1" ] && printf '%s' "$GLYPH_WORK" || printf '%s' "$GLYPH_GAME"; }

wm_toggle() {
  local verb; verb="$(wm_decide "$(wm_running)")"
  # debounce double-clicks/double-taps (mirror the PS mutex) with an atomic mkdir lock
  # — macOS has no flock(1), and mkdir is atomic on every POSIX fs. Steal a STALE lock
  # (>3s old: a prior run SIGKILLed before its EXIT trap fired) so it can never wedge.
  local lock="/tmp/wm-toggle.lock"
  if [ -d "$lock" ]; then
    local now lockts
    now=$(date +%s); lockts=$(stat -f %m "$lock" 2>/dev/null || echo "$now")
    if [ $(( now - lockts )) -ge 3 ]; then rmdir "$lock" 2>/dev/null || true; fi
  fi
  mkdir "$lock" 2>/dev/null || exit 0
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  yabai "--${verb}-service"
  printf '%s -> %s\n' "$(date +%FT%T)" "$verb" >> "/tmp/wm-toggle.log"
}

# run nothing when sourced by the test harness
if [ "${WM_TOGGLE_NOEXEC:-0}" != "1" ]; then
  case "${1:-}" in
    --state) wm_glyph "$(wm_running)" ;;
    *)       wm_toggle ;;
  esac
fi
