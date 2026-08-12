#!/bin/bash
# bar-toggle.sh — toggle SketchyBar visibility AND yabai's external_bar offset
# together, so hiding the bar lets windows reclaim the strip. macOS mirror of
# the Windows yasb-toggle.ps1 (Hyper+B / pwsh `bar`). Bound to Hyper+B B in
# Hammerspoon keys.lua.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

hidden=$(sketchybar --query bar | jq -r '.hidden')
if [ "$hidden" = "on" ] || [ "$hidden" = "true" ]; then
  sketchybar --bar hidden=off
  yabai -m config external_bar all:25:0   # keep in sync with yabairc:7
else
  sketchybar --bar hidden=on
  yabai -m config external_bar all:0:0
fi
