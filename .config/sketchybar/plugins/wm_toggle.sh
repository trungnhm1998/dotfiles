#!/usr/bin/env bash
# wm_toggle.sh — SketchyBar item for the yabai WM on/off (gaming) toggle.
#   mouse.clicked → flip yabai via wm-toggle.sh; otherwise render the state glyph.
# Distinct from kanata_mode (which flips the kanata keyboard layer).
WM_TOGGLE="$HOME/.config/yabai/scripts/wm-toggle.sh"

if [ "$SENDER" = "mouse.clicked" ]; then
  "$WM_TOGGLE"
fi

label="$("$WM_TOGGLE" --state)"
sketchybar --set "$NAME" label="$label"
