#!/usr/bin/env sh

# Defer to an active Hammerspoon mode: osd.lua drops this flag on mode-enter so
# focus/resize signals don't repaint over the mode (resize/service) border color.
[ -f "$HOME/.cache/yabai/wm-mode" ] && exit 0

if yabai -m query --windows --window | grep '"has-fullscreen-zoom":true'; then
  borders active_color=0xffe78284
else
  borders active_color=0xffca9ee6
fi
