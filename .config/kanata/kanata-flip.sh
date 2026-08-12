#!/bin/bash
# kanata-flip.sh — flip kanata's persistent base layer (base <-> gaming) over
# its TCP port. Shared by the SketchyBar kanata_mode pill click and the
# Hammerspoon Hyper+G hotkey. Feedback (pill label + toast) comes from
# kanata-layer-listener.sh reacting to the LayerChange event.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
STATE="$HOME/.cache/kanata/layer"
PORT="${KANATA_PORT:-10000}"

cur=$(cat "$STATE" 2>/dev/null)
[ "$cur" = "gaming" ] && next="base" || next="gaming"
exec 3<>"/dev/tcp/127.0.0.1/$PORT" 2>/dev/null || exit 0
printf '{"ChangeLayer":{"new":"%s"}}\n' "$next" >&3
exec 3<&- 3>&-
