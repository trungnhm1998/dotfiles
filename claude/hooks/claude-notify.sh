#!/usr/bin/env bash
# Claude Code "Notification" hook — fires when Claude needs permission or is waiting
# for your input. Reads the hook JSON payload on stdin and surfaces .message as a
# desktop notification. Delivery (tmux-native toast + cues, or a per-OS notifier) is
# shared with the Stop hook via lib/notify-lib.sh.

# DISABLED 2026-08-12: back to minimal Claude Code setup (no custom toasts/chips/badges).
# Remove the next two lines to re-enable; body below is untouched. Spec:
# docs/superpowers/specs/2026-08-12-claude-notify-minimal-design.md
# shellcheck disable=SC2317  # everything below is intentionally unreachable
exit 0

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/notify-lib.sh" 2>/dev/null || exit 0

payload="$(cat)"
message="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
[ -z "$message" ] && exit 0

cc_notify "Claude Code" "$message" notification
exit 0
