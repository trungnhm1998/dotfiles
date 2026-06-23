#!/bin/bash
# kanata_mode.sh — SketchyBar item for the kanata WORK/GAME indicator.
#   mouse.clicked → flip kanata's base layer over its TCP port.
#   any other run (initial/forced) → render the label from the state file.
# The listener drives live updates via `sketchybar --set`; this handles clicks + init.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
STATE="$HOME/.cache/kanata/layer"
PORT="${KANATA_PORT:-10000}"

render() {
  cur=$(cat "$STATE" 2>/dev/null)
  if [ "$cur" = "gaming" ]; then
    sketchybar --set "$NAME" label="🎮 GAME"
  else
    sketchybar --set "$NAME" label="⌨️ WORK"
  fi
}

case "$SENDER" in
  mouse.clicked)
    cur=$(cat "$STATE" 2>/dev/null)
    [ "$cur" = "gaming" ] && next="base" || next="gaming"
    printf '{"ChangeLayer":{"new":"%s"}}\n' "$next" | nc -w1 127.0.0.1 "$PORT"
    ;;
  *)
    render
    ;;
esac
