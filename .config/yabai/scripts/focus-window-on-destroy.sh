#!/bin/bash
# Restore focus to a remaining window when the focused one is destroyed.
# yabai/macOS don't auto-focus a sibling on close. Consumer: yabairc window_destroyed signal.
# yabai v7 query schema uses is-visible / has-focus (NOT the pre-v3 visible / focused).

focused=$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty')
if [[ -z "$focused" ]]; then
    target=$(yabai -m query --windows --space | jq -re 'first(.[] | select(."is-visible") | .id)')
    [[ -n "$target" ]] && yabai -m window --focus "$target"
fi
