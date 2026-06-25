#!/usr/bin/env sh

if yabai -m query --windows --window | grep '"has-fullscreen-zoom":true'; then
  borders active_color=0xffe78284
else
  borders active_color=0xffca9ee6
fi
