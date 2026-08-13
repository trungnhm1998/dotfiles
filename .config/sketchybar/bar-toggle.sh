#!/bin/bash
# bar-toggle.sh — toggle SketchyBar visibility AND yabai's external_bar offset
# together, so hiding the bar lets windows reclaim the strip. macOS mirror of
# the Windows yasb-toggle.ps1 (Hyper+B / pwsh `bar`). Bound to Hyper+B B in
# Hammerspoon keys.lua.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Marker persists the hidden choice across `sketchybar --reload` (which resets
# `hidden` to off); sketchybarrc re-applies it at the end of every reload.
MARKER="$HOME/.cache/sketchybar-hidden"

hidden=$(sketchybar --query bar | jq -r '.hidden')
if [ "$hidden" = "on" ] || [ "$hidden" = "true" ]; then
  sketchybar --bar hidden=off
  yabai -m config external_bar all:25:0   # keep in sync with yabairc:7
  rm -f "$MARKER"
else
  sketchybar --bar hidden=on
  yabai -m config external_bar all:0:0
  mkdir -p "$(dirname "$MARKER")" && touch "$MARKER"
fi
