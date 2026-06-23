#!/bin/bash
# cc_notify.sh — SketchyBar broker + click handler for Claude-agent notification chips.
#   (no arg, driven by subscribed events) -> render the anchor + per-agent items
#   jump '<pane>'  -> focus that tmux pane + clear it
#   clearall       -> drop all pending entries
#   click          -> anchor click: left = toggle dropdown, right/alt = toggle layout
# Pure logic lives in the notify-store / notify-render libs (unit-tested).
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
. "$HOME/.claude/hooks/lib/notify-store.sh"  2>/dev/null
. "$HOME/.claude/hooks/lib/notify-render.sh" 2>/dev/null
ANCHOR="cc_notify"

render(){
  # 1. clear-on-visit: drop pending entries for panes you're currently viewing.
  local vp
  while read -r vp; do [ -n "$vp" ] && ccn_clear "$vp"; done < <(
    tmux list-panes -a -F '#{pane_active} #{window_active} #{session_attached} #{pane_id}' 2>/dev/null | ccn_viewed_from_stream
  )
  # 2. prune entries whose pane no longer exists. Skip when the query came back empty
  #    (e.g. tmux down) so a transient failure never wipes the store.
  local live; live="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)"
  [ -n "$live" ] && ccn_prune $live

  # 3. rebuild items.
  local count mode; count="$(ccn_count)"; mode="$(ccn_mode_get)"
  if [ "${count:-0}" -eq 0 ]; then
    sketchybar --remove '/cc_notify\.agent\..*/' 2>/dev/null \
               --set "$ANCHOR" drawing=off popup.drawing=off
    return
  fi

  local args=(--remove '/cc_notify\.agent\..*/'
              --set "$ANCHOR" drawing=on icon=󰂞 label="$count")
  local key kind pane sess wname cmd cwd lbl icon col item
  while read -r key; do
    [ -n "$key" ] || continue
    kind="$(ccn_read_kind "$key")"; pane="%$key"
    sess="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null)"
    [ -n "$sess" ] || { ccn_clear "$key"; continue; }   # pane vanished mid-render
    wname="$(tmux display-message -p -t "$pane" '#{window_name}' 2>/dev/null)"
    cmd="$(tmux display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null)"
    cwd="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)"
    lbl="$(ccn_label "$wname" "$cmd" "$cwd")"
    icon="$(ccn_icon "$kind")"; col="$(ccn_color "$kind")"
    item="cc_notify.agent.$key"
    if [ "$mode" = expanded ]; then
      args+=(--add item "$item" right)
    else
      args+=(--add item "$item" popup."$ANCHOR")
    fi
    args+=(--set "$item" icon="$icon" icon.color="$col" label="$lbl"
           click_script="$0 jump '$pane'")
  done < <(ccn_list_keys)

  if [ "$mode" = collapsed ]; then
    args+=(--add item cc_notify.agent.clearall popup."$ANCHOR"
           --set cc_notify.agent.clearall icon=✕ label="clear all" click_script="$0 clearall")
  else
    args+=(--set "$ANCHOR" popup.drawing=off)
  fi
  sketchybar "${args[@]}"
}

case "${1:-$SENDER}" in
  jump)
    pane="$2"
    sess="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null)"
    eval "$(ccn_jump_cmd "$sess" "$pane")"   # shared focus sequence (see notify-render.sh)
    ccn_clear "$pane"
    sketchybar --set "$ANCHOR" popup.drawing=off
    sketchybar --trigger claude_notify_changed
    ;;
  clearall)
    ccn_clear_all
    sketchybar --set "$ANCHOR" popup.drawing=off
    sketchybar --trigger claude_notify_changed
    ;;
  click)
    if [ "$BUTTON" = right ] || [ "$MODIFIER" = alt ]; then
      ccn_mode_toggle
      sketchybar --set "$ANCHOR" popup.drawing=off
      sketchybar --trigger claude_notify_changed
    else
      sketchybar --set "$ANCHOR" popup.drawing=toggle
    fi
    ;;
  *) render ;;
esac
