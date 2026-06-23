#!/bin/bash
# Dynamic workspace strip for yabai: one query per event; show a space iff it
# has >=1 window OR is focused. Driven by yabai signals + SketchyBar
# space/app/display events. yabai is the source of truth.
# Spec: docs/superpowers/specs/2026-06-24-yabai-dynamic-workspaces-design.md
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

args=()
while read -r idx focus nwin; do
  if [[ "$focus" == "true" || "$nwin" -gt 0 ]]; then
    draw="on"
  else
    draw="off"
  fi
  args+=(--set "space.$idx" drawing="$draw" background.drawing="$focus")
done < <(yabai -m query --spaces | jq -r '.[] | "\(.index) \(.["has-focus"]) \(.windows | length)"')

[[ ${#args[@]} -gt 0 ]] && sketchybar "${args[@]}"
