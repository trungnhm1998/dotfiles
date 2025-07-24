#!/usr/bin/env sh

if yabai -m query --windows --window | grep '"has-fullscreen-zoom":true'; then
  borders active_color=0xffff0000
else
  borders active_color=0xffe1e3e4
fi
