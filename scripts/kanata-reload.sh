#!/bin/bash
# Reload the kanata LaunchDaemon after editing kanata.kbd.
# Kanata has no auto-reload-on-save on macOS, so run this after every edit.
set -euo pipefail

# Validate first so a bad edit can't take down the remap.
if ! kanata --cfg "$HOME/.config/kanata/kanata.kbd" --check -q; then
  echo "Config invalid — not reloading." >&2
  exit 1
fi

sudo launchctl kickstart -k system/dev.kanata.kanata
echo "kanata reloaded."
