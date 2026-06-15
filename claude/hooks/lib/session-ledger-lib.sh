#!/usr/bin/env bash
# Shared session-ledger logic. SOURCE this, don't execute.
# A ledger is a per-session JSON file under $(ledger_dir). Honors $CLAUDE_LEDGER_DIR
# so tests run against a temp dir. All functions fail open (no-op) on missing files.
# Concurrency: read-modify-write (jq > tmp && mv) is single-writer. Concurrent bumps
# can lose an update; acceptable for a nudge heuristic (no locking by design).

ledger_dir(){ printf '%s' "${CLAUDE_LEDGER_DIR:-$HOME/.claude/.session-ledger}"; }
ledger_path(){ printf '%s/%s.json' "$(ledger_dir)" "$1"; }
project_key(){ printf '%s' "$1" | cksum | cut -d' ' -f1; }
now_iso(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

ledger_init(){
  local sid="$1" cwd="$2" proj="$3" f
  f="$(ledger_path "$sid")"
  mkdir -p "$(ledger_dir)" 2>/dev/null
  [ -f "$f" ] && return 0
  jq -n --arg sid "$sid" --arg cwd "$cwd" --arg proj "$proj" --arg t "$(now_iso)" '
    {session_id:$sid, cwd:$cwd, project:$proj, turns:0,
     signals:{files_written:0,files_edited:0,git_commits:0,prs_opened:0},
     signals_at_capture:{files_written:0,files_edited:0,git_commits:0,prs_opened:0},
     nudge_level:0, precompact_blocked:false, last_capture_at:null, started_at:$t}' > "$f"
}

ledger_get(){
  local f; f="$(ledger_path "$1")"
  [ -f "$f" ] || { printf ''; return 0; }
  # `// empty` would swallow JSON false (jq treats false as empty); select+tostring
  # preserves "false"/"0" while still returning empty for null/missing keys.
  jq -r "($2 | select(. != null) | tostring) // empty" "$f" 2>/dev/null
}

ledger_bump(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  jq --arg k "$2" --argjson n "${3:-1}" '.signals[$k] = ((.signals[$k] // 0) + $n)' "$f" > "$tmp" && mv "$tmp" "$f"
}

ledger_delta(){
  local f; f="$(ledger_path "$1")"; [ -f "$f" ] || { printf '0'; return 0; }
  jq -r --arg k "$2" '((.signals[$k] // 0) - (.signals_at_capture[$k] // 0))' "$f" 2>/dev/null
}

ledger_meaningful(){
  local sid="$1" fw fe gc pr files
  fw="$(ledger_delta "$sid" files_written)"; fe="$(ledger_delta "$sid" files_edited)"
  gc="$(ledger_delta "$sid" git_commits)";   pr="$(ledger_delta "$sid" prs_opened)"
  fw="${fw:-0}"; fe="${fe:-0}"; gc="${gc:-0}"; pr="${pr:-0}"  # empty delta -> 0 (defensive)
  files=$(( fw + fe ))
  if [ "$files" -ge "${WIKI_THRESHOLD_FILES:-3}" ] || \
     [ "$gc" -ge "${WIKI_THRESHOLD_COMMITS:-1}" ] || \
     [ "$pr" -ge 1 ]; then
    return 0
  fi
  return 1
}

ledger_bump_nudge(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || { printf '0'; return 0; }
  tmp="$(mktemp)"
  jq '.nudge_level = (.nudge_level + 1)' "$f" > "$tmp" && mv "$tmp" "$f"
  jq -r '.nudge_level' "$f"
}

ledger_mark_captured(){
  local f tmp; f="$(ledger_path "$1")"; [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  jq --arg t "$(now_iso)" '
    .signals_at_capture = .signals
    | .nudge_level = 0
    | .precompact_blocked = false
    | .last_capture_at = $t' "$f" > "$tmp" && mv "$tmp" "$f"
}

pointer_write(){
  local key="$1" sid="$2" proj="$3" unc="$4" sum="$5" d f
  d="$(ledger_dir)/by-project"; mkdir -p "$d" 2>/dev/null
  f="$d/$key.json"
  jq -n --arg sid "$sid" --arg p "$proj" --argjson u "$unc" --arg s "$sum" --arg t "$(now_iso)" \
    '{session_id:$sid, project:$p, uncaptured:$u, summary:$s, updated_at:$t}' > "$f"
}

pointer_get(){
  local f; f="$(ledger_dir)/by-project/$1.json"
  [ -f "$f" ] || { printf ''; return 0; }
  jq -r "($2 | select(. != null) | tostring) // empty" "$f" 2>/dev/null
}
