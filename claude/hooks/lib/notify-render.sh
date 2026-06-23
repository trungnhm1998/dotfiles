#!/usr/bin/env bash
# notify-render.sh — pure presentation helpers for the cc_notify SketchyBar plugin.
# No tmux/sketchybar calls; the plugin feeds tmux output into the parser and uses the
# formatters to build labels/icons. Kept pure so it is unit-testable.

# stdin: lines "<pane_active> <window_active> <session_attached> <pane_id>"
# stdout: pane ids currently VIEWED (active pane + active window + an attached session).
ccn_viewed_from_stream(){
  local pa wa sa pid
  while read -r pa wa sa pid; do
    [ "$pa" = 1 ] || continue
    [ "$wa" = 1 ] || continue
    case "$sa" in ''|0|*[!0-9]*) continue ;; esac
    printf '%s\n' "$pid"
  done
}

# <window_name> <pane_cmd> <cwd> -> short label (<=12 chars).
ccn_label(){
  local wname="$1" cmd="$2" cwd="$3" out
  case "$wname" in
    ''|zsh|bash|sh|fish|nu|"$cmd") out="$(basename "$cwd" 2>/dev/null)" ;;
    *) out="$wname" ;;
  esac
  [ -n "$out" ] || out="agent"
  printf '%.12s' "$out"
}

ccn_icon(){  case "$1" in stop) printf '󰗠' ;; *) printf '󰂞' ;; esac; }
ccn_color(){ case "$1" in stop) printf '0xffa6d189' ;; *) printf '0xffef9f76' ;; esac; }

# <session> <pane_id> -> one shell-command string that focuses that tmux pane and
# raises WezTerm. Shared by the toast (terminal-notifier -execute, a detached `sh -c`)
# and the plugin (via eval). Absolute tmux path: the toast's minimal shell shadows
# `tmux` with a plugin function, and select-window/-pane target the pane id so it
# works across sessions.
ccn_jump_cmd(){
  local tb; tb="$(command -v tmux 2>/dev/null)"; [ -n "$tb" ] || tb=/opt/homebrew/bin/tmux
  printf "%s switch-client -t '%s' 2>/dev/null; %s select-window -t '%s' 2>/dev/null; %s select-pane -t '%s' 2>/dev/null; /usr/bin/open -b com.github.wez.wezterm" \
    "$tb" "$1" "$tb" "$2" "$tb" "$2"
}
