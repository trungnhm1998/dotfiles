#!/usr/bin/env bash
# notify-store.sh — persistence for Claude-agent pending notifications.
# One file per waiting agent under $CCN_HOME/pending, named by the tmux pane id's
# numeric key; content is the kind (notification|stop). A mode file holds the
# SketchyBar display mode. All paths honor $CCN_HOME so tests isolate to a tmpdir.

ccn_home(){ printf '%s' "${CCN_HOME:-$HOME/.cache/claude-notify}"; }
ccn_pending_dir(){ printf '%s/pending' "$(ccn_home)"; }
ccn_mode_file(){ printf '%s/mode' "$(ccn_home)"; }

# %23 -> 23 ; defensive: keep digits only
ccn_pane_key(){ printf '%s' "${1//[!0-9]/}"; }

ccn_write_pending(){            # <pane_id> <kind>
  local key dir; key="$(ccn_pane_key "$1")"
  [ -n "$key" ] || return 0
  dir="$(ccn_pending_dir)"; mkdir -p "$dir" 2>/dev/null
  printf '%s' "${2:-notification}" > "$dir/$key"
}

ccn_read_kind(){ cat "$(ccn_pending_dir)/$1" 2>/dev/null; }

ccn_list_keys(){                # keys, one per line, numerically sorted
  local dir; dir="$(ccn_pending_dir)"
  [ -d "$dir" ] || return 0
  ls -1 "$dir" 2>/dev/null | sort -n
}

ccn_count(){ ccn_list_keys | wc -l | tr -dc '0-9'; }

ccn_clear(){                    # <pane_id-or-key>
  local key; key="$(ccn_pane_key "$1")"
  [ -n "$key" ] && rm -f "$(ccn_pending_dir)/$key" 2>/dev/null
  return 0
}

ccn_clear_all(){ rm -f "$(ccn_pending_dir)/"* 2>/dev/null; return 0; }

ccn_prune(){                    # <live ids/keys...>: remove entries not in the set
  [ "$#" -gt 0 ] || return 0    # no live set provided -> safety no-op (never wipe on a failed query)
  local dir live k f; dir="$(ccn_pending_dir)"
  [ -d "$dir" ] || return 0
  live=" "
  for k in "$@"; do live="$live$(ccn_pane_key "$k") "; done
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    k="$(basename "$f")"
    case "$live" in *" $k "*) : ;; *) rm -f "$f" 2>/dev/null ;; esac
  done
}

ccn_mode_get(){
  local m; m="$(cat "$(ccn_mode_file)" 2>/dev/null)"
  [ "$m" = expanded ] && printf 'expanded' || printf 'collapsed'
}
ccn_mode_set(){ mkdir -p "$(ccn_home)" 2>/dev/null; printf '%s' "$1" > "$(ccn_mode_file)"; }
ccn_mode_toggle(){ [ "$(ccn_mode_get)" = collapsed ] && ccn_mode_set expanded || ccn_mode_set collapsed; }
