#!/bin/bash
# kanata_mode.sh — SketchyBar item for the kanata WORK/GAME indicator.
#   mouse.clicked → delegate to kanata-flip.sh to flip the base layer.
#   any other run (initial/forced) → render the label from the state file.
# The listener drives live updates via `sketchybar --set`; this handles clicks + init.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
STATE="$HOME/.cache/kanata/layer"

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
    "$HOME/.config/kanata/kanata-flip.sh"
    ;;
  *)
    render
    ;;
esac
