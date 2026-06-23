#!/bin/bash
# kanata-layer-listener.sh — subscribe to kanata's TCP layer-change stream and
# reflect the persistent WORK/GAME mode via SketchyBar + a terminal-notifier toast.
# Runs as a USER LaunchAgent (needs the Aqua session). LaunchAgents get a minimal
# PATH, so set it explicitly for the brew tools.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
set -u

PORT="${KANATA_PORT:-10000}"
STATE="$HOME/.cache/kanata/layer"
mkdir -p "$(dirname "$STATE")"
last=""

render() {                       # $1 = gaming | base
  case "$1" in
    gaming) icon="🎮"; word="GAME" ;;
    base)   icon="⌨️";  word="WORK" ;;
    *) return ;;
  esac
  printf '%s' "$1" > "$STATE"
  sketchybar --set kanata_mode label="$icon $word" 2>/dev/null
  terminal-notifier -title "kanata" -message "$icon $word mode" -group kanata-mode 2>/dev/null
}

while true; do
  if exec 3<>"/dev/tcp/127.0.0.1/$PORT" 2>/dev/null; then
    printf '{"RequestCurrentLayerName":{}}\n' >&3            # seed current state on connect
    while IFS= read -r line <&3; do
      layer=$(printf '%s' "$line" | jq -r '.LayerChange.new // .CurrentLayerName.name // empty' 2>/dev/null)
      case "$layer" in
        gaming|base) ;;          # persistent states we reflect
        *) continue ;;           # ignore transient nav/funcs/funcs-game + parse misses
      esac
      [ "$layer" = "$last" ] && continue
      last="$layer"
      render "$layer"
    done
    exec 3<&- 3>&-               # connection dropped (kanata restarted)
  fi
  last=""                        # force a re-render after reconnect
  sleep 1
done
