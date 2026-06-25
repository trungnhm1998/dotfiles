#!/usr/bin/env bash
# Shared desktop-notification delivery for Claude Code hooks (Notification + Stop).
#
# cc_notify "<title>" "<body>" surfaces a notification two ways at once:
#   1. In-terminal cue (inside tmux): a raw BEL on the emitting pane's tty. tmux flags
#      that window so you can see WHICH tab is waiting (status-bar bell badge, see
#      @catppuccin_window_text); WezTerm also marks the tab and rings the audible bell.
#   2. Desktop toast (per-OS native notifier):
#        * macOS   -> terminal-notifier, posted under its OWN identity. Clicking the
#          toast focuses the exact tmux window/pane that fired and raises WezTerm.
#        * Linux   -> notify-send.
#        * Windows -> the machine-local PowerShell notifier.
#
# Why terminal-notifier and NOT WezTerm's OSC 777 toast (the previous approach):
#   - macOS files a banner straight to Notification Center with NO on-screen pop when
#     it is attributed to the *frontmost* app -- and WezTerm is usually frontmost. OSC
#     777 toasts are attributed to WezTerm, so they were invisible on first show.
#     terminal-notifier posts under its own bundle, so it always pops.
#   - OSC 777 can't carry a click action; terminal-notifier -execute can.
#   - Do NOT pass `-sender com.github.wez.wezterm`: that re-attributes the banner to
#     WezTerm and re-introduces the frontmost-app suppression we just escaped.
# One source of truth so the Notification and Stop hooks deliver identically.

# Pending-store + shared helpers (pane-keyed entries; ccn_jump_cmd shared with the plugin).
. "$(dirname "${BASH_SOURCE[0]}")/notify-store.sh"  2>/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/notify-render.sh" 2>/dev/null

# Resolve a cached WezTerm icon PNG for the toast thumbnail. Echoes the path, or nothing
# if it can't be produced. Generated once from WezTerm's .icns: macOS Sequoia ignores
# -appIcon, and -sender would re-attribute the toast to WezTerm (→ frontmost-app
# suppression), so a -contentImage thumbnail is the only branding that keeps the banner
# reliable. The corner icon stays terminal-notifier's.
_cc_wezterm_icon() {
  local icon="${XDG_CACHE_HOME:-$HOME/.cache}/claude-notify/wezterm.png"
  if [ ! -f "$icon" ]; then
    command -v sips >/dev/null 2>&1 || return 0
    local app icns
    app="$(osascript -e 'POSIX path of (path to application id "com.github.wez.wezterm")' 2>/dev/null)"
    [ -n "$app" ] || return 0
    icns="$(ls "${app%/}/Contents/Resources/"*.icns 2>/dev/null | head -1)"
    [ -n "$icns" ] || return 0
    mkdir -p "$(dirname "$icon")" 2>/dev/null
    sips -s format png "$icns" --out "$icon" >/dev/null 2>&1 || return 0
  fi
  [ -f "$icon" ] && printf '%s' "$icon"
}

cc_notify() {
  local title="$1" body="$2" kind="${3:-notification}"
  [ -z "$body" ] && return 0

  # --- In-terminal cue: inside tmux, BEL the emitting pane so tmux flags its window. ---
  local tmux_bin="" tmux_pane=""
  if [ -n "${TMUX:-}" ]; then
    tmux_bin="$(command -v tmux 2>/dev/null)"
    [ -z "$tmux_bin" ] && tmux_bin="/opt/homebrew/bin/tmux"
    tmux_pane="${TMUX_PANE:-}"
    local tty
    if [ -n "$tmux_pane" ]; then
      tty="$("$tmux_bin" display-message -p -t "$tmux_pane" '#{pane_tty}' 2>/dev/null)"
    else
      tmux_pane="$("$tmux_bin" display-message -p '#{pane_id}' 2>/dev/null)"
      tty="$("$tmux_bin" display-message -p '#{pane_tty}' 2>/dev/null)"
    fi
    [ -n "$tty" ] && { printf '\a' > "$tty"; } 2>/dev/null   # BEL -> tmux window bell flag
    # Persist a pending entry + nudge SketchyBar (the always-visible chip channel).
    if [ -n "$tmux_pane" ] && command -v ccn_write_pending >/dev/null 2>&1; then
      ccn_write_pending "$tmux_pane" "$kind"
      local sb; sb="$(command -v sketchybar 2>/dev/null)"; [ -n "$sb" ] || sb=/opt/homebrew/bin/sketchybar
      "$sb" --trigger claude_notify_changed 2>/dev/null
    fi
  fi

  # --- Desktop toast: per-OS native notifier. ---
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      # Tab-badge cue: record which WezTerm pane is waiting, keyed by $WEZTERM_PANE, so the
      # tab bar can flag it without switching (see .config/wezterm/tabline_claude_badge.lua +
      # the update-status poller in wezterm.lua). File channel -- robust on Windows, where
      # OSC-through-ConPTY to WezTerm does not arrive. CC_ALERT_DIR is a test seam.
      if [ -n "${WEZTERM_PANE:-}" ]; then
        local alert_dir="${CC_ALERT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-notify/wezterm-alerts}"
        mkdir -p "$alert_dir" 2>/dev/null \
          && printf '%s' "$kind" > "$alert_dir/$WEZTERM_PANE" 2>/dev/null || true
      fi
      # Desktop toast via the repo-vendored notifier (resolved relative to this lib,
      # so it rides the claude/ -> ~/.claude symlink; no machine-local C:\Tools file).
      local notifier_sh; notifier_sh="$(dirname "${BASH_SOURCE[0]}")/../bin/claude-notify.ps1"
      if [ -f "$notifier_sh" ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$notifier_sh")" \
          -Title "$title" -Message "$body"
      fi
      ;;
    Darwin)
      if command -v terminal-notifier >/dev/null 2>&1; then
        # WezTerm thumbnail on the right of the toast (see _cc_wezterm_icon).
        local icon; icon="$(_cc_wezterm_icon)"
        local img=(); [ -n "$icon" ] && img=(-contentImage "file://$icon")
        if [ -n "$tmux_pane" ] && [ -n "$tmux_bin" ] && command -v ccn_jump_cmd >/dev/null 2>&1; then
          # Click -> jump to the exact tmux window/pane that fired, then raise WezTerm.
          # switch-client (no -c) acts on the most-recent client; select-window/pane
          # target the pane id directly so it works across sessions.
          local session focus_cmd
          session="$("$tmux_bin" display-message -p -t "$tmux_pane" '#{session_name}' 2>/dev/null)"
          focus_cmd="$(ccn_jump_cmd "$session" "$tmux_pane")"
          terminal-notifier -title "$title" -message "$body" -group "claude-code" "${img[@]}" -execute "$focus_cmd"
        else
          # Not in tmux (or jump helper unavailable): a click just raises WezTerm.
          terminal-notifier -title "$title" -message "$body" -group "claude-code" "${img[@]}" -activate "com.github.wez.wezterm"
        fi
      elif command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\""
      fi
      ;;
    *)
      command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$body"
      ;;
  esac
}
