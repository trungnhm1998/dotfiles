# SketchyBar Claude-agent Notification Chips — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show which Claude agents are waiting on you as persistent, clickable SketchyBar chips that survive until you visit the agent, each jumping to the exact tmux pane.

**Architecture:** Claude's `Notification`/`Stop` hooks write one tiny file per waiting agent (keyed by tmux pane id) into a pending store and nudge SketchyBar. A SketchyBar broker item re-renders on that nudge (and on focus/space events): it clears entries for panes you're currently viewing, prunes dead panes, then draws either inline chips or a dropdown depending on a runtime mode toggle. Clicking a chip jumps to its pane and clears it. Purely additive to the existing tmux bell badge + `terminal-notifier` toast.

**Tech Stack:** Bash, tmux, SketchyBar (FelixKratz), `jq` (already used), Catppuccin Frappe theme, Nerd Font glyphs.

## Global Constraints

- **Platform:** macOS (tmux + WezTerm + SketchyBar). Claude **outside tmux** writes no chip (toast still fires).
- **Pending store:** `~/.cache/claude-notify/pending/<numeric-pane-key>`; file content = kind (`notification` | `stop`). Mode file: `~/.cache/claude-notify/mode` (default `collapsed`). All paths honor `$CCN_HOME` for tests.
- **Pane key:** tmux pane id `%23` → numeric key `23`; reconstruct as `%23` when targeting tmux.
- **Item names:** anchor `cc_notify`; per-agent `cc_notify.agent.<key>`; clear-all row `cc_notify.agent.clearall`. Custom event: `claude_notify_changed`.
- **Glyphs / colors (Catppuccin Frappe):** needs-input `󰂞` peach `0xffef9f76`; finished `󰗠` green `0xffa6d189`.
- **Binary fallbacks (minimal-env contexts):** `sketchybar` → `/opt/homebrew/bin/sketchybar`; `tmux` → `/opt/homebrew/bin/tmux`.
- **Shell style (AGENTS.md):** 2-space indent, quote expansions. Libs in `claude/hooks/lib/` use `#!/usr/bin/env bash`; SketchyBar plugins use `#!/bin/bash` + `export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"` (match existing plugins).
- **Tests:** bash, `source _harness.sh`, isolate with `CCN_HOME="$(mktemp -d)"`, run via `bash claude/hooks/tests/run-tests.sh`.
- **Git:** conventional-commit messages; **no AI attribution / no `Co-Authored-By` trailers**.

---

### Task 1: Pending-store library (`notify-store.sh`)

The persistence layer: write/read/list/clear/prune pending entries and get/set the display mode. Pure file ops, fully unit-tested with an isolated `CCN_HOME`.

**Files:**
- Create: `claude/hooks/lib/notify-store.sh`
- Test: `claude/hooks/tests/test-notify-store.sh`

**Interfaces:**
- Consumes: nothing.
- Produces (sourced by Tasks 3 & 4):
  - `ccn_home` → `$CCN_HOME` or `$HOME/.cache/claude-notify`
  - `ccn_pending_dir`, `ccn_mode_file` → derived paths
  - `ccn_pane_key <pane_id>` → digits only (`%23`→`23`)
  - `ccn_write_pending <pane_id> <kind>` → writes `pending/<key>` = kind (no-op on empty id)
  - `ccn_read_kind <key>` → kind string (stdout)
  - `ccn_list_keys` → keys, one per line, numerically sorted
  - `ccn_count` → integer count
  - `ccn_clear <pane_id-or-key>`; `ccn_clear_all`
  - `ccn_prune <live_ids...>` → remove entries whose key ∉ live set
  - `ccn_mode_get` (→`collapsed`|`expanded`), `ccn_mode_set <mode>`, `ccn_mode_toggle`

- [ ] **Step 1: Write the failing test**

Create `claude/hooks/tests/test-notify-store.sh`:

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/notify-store.sh"
export CCN_HOME="$(mktemp -d)"

# pane key sanitization
assert_eq "$(ccn_pane_key '%23')" "23" "pane_key strips %"
assert_eq "$(ccn_pane_key '%7')"  "7"  "pane_key %7 -> 7"

# write + read kind, keyed by pane; same pane overwrites (dedup)
ccn_write_pending "%7" notification
assert_eq "$(ccn_read_kind 7)" "notification" "write/read kind"
ccn_write_pending "%7" stop
assert_eq "$(ccn_read_kind 7)" "stop" "same pane overwrites (dedup)"
assert_eq "$(ccn_count)" "1" "count=1 after dedup"

# second pane; list sorted numerically
ccn_write_pending "%12" notification
assert_eq "$(ccn_count)" "2" "count=2 with two panes"
assert_eq "$(ccn_list_keys | tr '\n' ' ')" "7 12 " "list sorted numerically"

# clear one
ccn_clear "%7"
assert_eq "$(ccn_count)" "1" "clear removes one"
assert_eq "$(ccn_read_kind 7)" "" "cleared entry gone"

# prune keeps only live keys
ccn_write_pending "%7" notification
ccn_prune "%12"
assert_eq "$(ccn_read_kind 7)"  "" "prune drops dead pane 7"
assert_eq "$(ccn_read_kind 12)" "notification" "prune keeps live pane 12"

# prune with NO live args is a safety no-op (never wipe the store on a failed tmux query)
nb="$(ccn_count)"
ccn_prune
assert_eq "$(ccn_count)" "$nb" "prune with no args is a no-op (safety)"

# clear all
ccn_clear_all
assert_eq "$(ccn_count)" "0" "clear_all empties store"

# empty pane id writes nothing
ccn_write_pending "" notification
assert_eq "$(ccn_count)" "0" "empty pane id writes nothing"

# mode get/set/toggle (default collapsed)
assert_eq "$(ccn_mode_get)" "collapsed" "default mode collapsed"
ccn_mode_set expanded
assert_eq "$(ccn_mode_get)" "expanded" "mode set expanded"
ccn_mode_toggle
assert_eq "$(ccn_mode_get)" "collapsed" "toggle back to collapsed"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-notify-store.sh`
Expected: FAIL — `notify-store.sh` does not exist / functions undefined.

- [ ] **Step 3: Write the minimal implementation**

Create `claude/hooks/lib/notify-store.sh`:

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-notify-store.sh`
Expected: PASS — `--- N run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/notify-store.sh claude/hooks/tests/test-notify-store.sh
git commit -m "feat(claude): notify-store lib for pending Claude-agent notifications"
```

---

### Task 2: Pure render helpers (`notify-render.sh`)

The presentation logic: which panes are "viewed", the chip label, and the per-kind icon/color. No tmux/sketchybar calls — the plugin pipes tmux output into the parser and uses the formatters. Fully unit-tested.

**Files:**
- Create: `claude/hooks/lib/notify-render.sh`
- Test: `claude/hooks/tests/test-notify-render.sh`

**Interfaces:**
- Consumes: nothing.
- Produces (sourced by Task 4):
  - `ccn_viewed_from_stream` — stdin lines `<pane_active> <window_active> <session_attached> <pane_id>`; stdout pane ids that are viewed (all three truthy, session_attached a positive integer)
  - `ccn_label <window_name> <pane_cmd> <cwd>` → ≤12-char label; uses window name unless empty / a generic shell name / equal to the command, else cwd basename
  - `ccn_icon <kind>` → `󰗠` for stop, else `󰂞`
  - `ccn_color <kind>` → `0xffa6d189` for stop, else `0xffef9f76`

- [ ] **Step 1: Write the failing test**

Create `claude/hooks/tests/test-notify-render.sh`:

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../lib/notify-render.sh"

# viewed parser: viewed iff pane_active=1 AND window_active=1 AND session_attached>0
out="$(printf '%s\n' \
  "1 1 1 %5" \
  "1 1 0 %6" \
  "0 1 1 %7" \
  "1 0 1 %8" | ccn_viewed_from_stream | tr '\n' ' ')"
assert_eq "$out" "%5 " "only the fully-viewed pane is emitted"

# label: manual window name (not generic, != command) wins
assert_eq "$(ccn_label 'nmd-build' 'claude' '/Users/x/dev/neo-match')" "nmd-build" "manual window name used"
# label: name == command -> cwd basename
assert_eq "$(ccn_label 'claude' 'claude' '/Users/x/dev/neo-match')" "neo-match" "name==cmd -> cwd basename"
# label: generic shell name -> cwd basename (allow-rename is off, names linger as 'zsh')
assert_eq "$(ccn_label 'zsh' 'claude' '/Users/x/dev/neo-match')" "neo-match" "generic shell name -> cwd basename"
# label: truncated to 12 chars
assert_eq "$(ccn_label 'supercalifragilistic' 'x' '/p')" "supercalifra" "label truncated to 12 chars"

# icon + color per kind
assert_eq "$(ccn_icon notification)"  "󰂞" "needs-input icon"
assert_eq "$(ccn_icon stop)"          "󰗠" "finished icon"
assert_eq "$(ccn_color notification)" "0xffef9f76" "needs-input color peach"
assert_eq "$(ccn_color stop)"         "0xffa6d189" "finished color green"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-notify-render.sh`
Expected: FAIL — `notify-render.sh` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `claude/hooks/lib/notify-render.sh`:

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-notify-render.sh`
Expected: PASS — `--- N run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/notify-render.sh claude/hooks/tests/test-notify-render.sh
git commit -m "feat(claude): notify-render helpers (viewed parser, label, icon, color)"
```

---

### Task 3: Wire `cc_notify` to write a pending entry + nudge SketchyBar

`cc_notify` gains a `kind` arg; inside tmux it persists a pending entry and triggers `claude_notify_changed`. The two hook scripts pass their kind. The BEL, toast, and focus-gate are unchanged.

**Files:**
- Modify: `claude/hooks/lib/notify-lib.sh` (source store lib; add `kind` param; pending-write + trigger)
- Modify: `claude/hooks/claude-notify.sh:13` (pass `notification`)
- Modify: `claude/hooks/claude-stop-notify.sh:29` (pass `stop`)
- Test: `claude/hooks/tests/test-cc-notify-pending.sh`

**Interfaces:**
- Consumes: `ccn_write_pending` (Task 1).
- Produces: `cc_notify "<title>" "<body>" [kind]` — `kind` defaults to `notification`.

- [ ] **Step 1: Write the failing test**

Create `claude/hooks/tests/test-cc-notify-pending.sh`:

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"

export CCN_HOME="$(mktemp -d)"
# Pre-seed the wezterm icon cache so _cc_wezterm_icon returns instantly (no sips/osascript).
export XDG_CACHE_HOME="$(mktemp -d)"; mkdir -p "$XDG_CACHE_HOME/claude-notify"; : > "$XDG_CACHE_HOME/claude-notify/wezterm.png"

# Stub external commands so cc_notify runs hermetically.
STUB="$(mktemp -d)"
cat > "$STUB/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"#{pane_tty}"*)      echo "/dev/null" ;;
  *"#{session_name}"*)  echo "work" ;;
  *"#{pane_id}"*)       echo "%7" ;;
  *) echo "" ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/sketchybar"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/terminal-notifier"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

. "$(dirname "$0")/../lib/notify-lib.sh"

# Inside tmux: writes a pending entry keyed by the pane, recording the kind.
export TMUX="x" TMUX_PANE="%7"
cc_notify "Claude Code" "needs you" notification
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "notification" "writes pending kind=notification keyed by pane"
cc_notify "Claude Code" "done" stop
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "stop" "same pane overwrites with kind=stop"

# Default kind is notification when omitted.
rm -f "$CCN_HOME/pending/7"
cc_notify "Claude Code" "hey"
assert_eq "$(cat "$CCN_HOME/pending/7" 2>/dev/null)" "notification" "kind defaults to notification"

# Outside tmux: no pending entry.
rm -rf "$CCN_HOME/pending"
unset TMUX TMUX_PANE
cc_notify "Claude Code" "hi" notification
test -n "$(ls -A "$CCN_HOME/pending" 2>/dev/null)"; assert_exit "$?" "1" "no pending entry when not in tmux"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-cc-notify-pending.sh`
Expected: FAIL — `cc_notify` ignores `kind` and writes nothing to the store yet.

- [ ] **Step 3: Add the store source line to `notify-lib.sh`**

At the top of `claude/hooks/lib/notify-lib.sh`, immediately after the header comment block (before `_cc_wezterm_icon`), add:

```bash
# Pending-store helpers (pane-keyed "who's waiting" entries for the SketchyBar chips).
. "$(dirname "${BASH_SOURCE[0]}")/notify-store.sh" 2>/dev/null
```

- [ ] **Step 4: Add the `kind` param and pending-write to `cc_notify`**

In `claude/hooks/lib/notify-lib.sh`, change the function signature line:

```bash
cc_notify() {
  local title="$1" body="$2"
```

to:

```bash
cc_notify() {
  local title="$1" body="$2" kind="${3:-notification}"
```

Then, still inside the `if [ -n "${TMUX:-}" ]; then ... fi` block, **after** the BEL line
`[ -n "$tty" ] && { printf '\a' > "$tty"; } 2>/dev/null   # BEL -> tmux window bell flag`,
add (inside the same `if` block, after the BEL line and before its closing `fi`):

```bash
    # Persist a pending entry + nudge SketchyBar (the always-visible chip channel).
    if [ -n "$tmux_pane" ] && command -v ccn_write_pending >/dev/null 2>&1; then
      ccn_write_pending "$tmux_pane" "$kind"
      local sb; sb="$(command -v sketchybar 2>/dev/null)"; [ -n "$sb" ] || sb=/opt/homebrew/bin/sketchybar
      "$sb" --trigger claude_notify_changed 2>/dev/null
    fi
```

- [ ] **Step 5: Pass the kind from the two hooks**

In `claude/hooks/claude-notify.sh`, change line 13:

```bash
cc_notify "Claude Code" "$message"
```

to:

```bash
cc_notify "Claude Code" "$message" notification
```

In `claude/hooks/claude-stop-notify.sh`, change line 29:

```bash
cc_notify "Claude Code" "finished — back to you"
```

to:

```bash
cc_notify "Claude Code" "finished — back to you" stop
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-cc-notify-pending.sh`
Expected: PASS — `--- N run, 0 failed ---`.

- [ ] **Step 7: Run the whole hook suite (no regressions)**

Run: `bash claude/hooks/tests/run-tests.sh`
Expected: every `test-*.sh` ends `0 failed`; overall exit 0.

- [ ] **Step 8: Commit**

```bash
git add claude/hooks/lib/notify-lib.sh claude/hooks/claude-notify.sh claude/hooks/claude-stop-notify.sh claude/hooks/tests/test-cc-notify-pending.sh
git commit -m "feat(claude): cc_notify writes pending entry + triggers sketchybar"
```

---

### Task 4: SketchyBar broker plugin (`cc_notify.sh`)

The render + click/dispatch logic. On a render it clears viewed panes, prunes dead ones, then rebuilds the anchor + per-agent items per the current mode. Click subcommands handle jump / clear-all / anchor-toggle. Integration glue — verified by `bash -n` + a live smoke test (the pure logic it depends on is already tested in Tasks 1–2).

**Files:**
- Create: `.config/sketchybar/plugins/cc_notify.sh`

**Interfaces:**
- Consumes: `notify-store.sh` + `notify-render.sh` (sourced by absolute path from `$HOME/.claude/hooks/lib/`).
- Produces: invoked four ways — as the anchor `script` (no arg → render), and as `cc_notify.sh jump '<pane>'`, `cc_notify.sh clearall`, `cc_notify.sh click` (from `click_script`).

- [ ] **Step 1: Write the plugin**

Create `.config/sketchybar/plugins/cc_notify.sh`:

```bash
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
    tmux switch-client -t "$sess" 2>/dev/null
    tmux select-window -t "$pane" 2>/dev/null
    tmux select-pane   -t "$pane" 2>/dev/null
    /usr/bin/open -b com.github.wez.wezterm
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
```

- [ ] **Step 2: Make it executable + syntax-check**

```bash
chmod +x .config/sketchybar/plugins/cc_notify.sh
bash -n .config/sketchybar/plugins/cc_notify.sh && echo "syntax OK"
```

Expected: `syntax OK`. If `shellcheck` is installed: `shellcheck -S error .config/sketchybar/plugins/cc_notify.sh` (expected: no errors; SC2086 word-splitting on the intentional `ccn_prune $live` is acceptable).

- [ ] **Step 3: Commit** (wiring + live smoke come in Task 5)

```bash
git add .config/sketchybar/plugins/cc_notify.sh
git commit -m "feat(sketchybar): cc_notify plugin — render + click/toggle for notify chips"
```

---

### Task 5: Wire the anchor item into `sketchybarrc`

Register the custom event, add the hidden-when-empty anchor with its broker `script` + `click_script`, subscribe it to the refresh events, and fire an initial render.

**Files:**
- Modify: `.config/sketchybar/sketchybarrc` (add a block after the `kanata_mode` block, ~line 108)

**Interfaces:**
- Consumes: `cc_notify.sh` (Task 4), event `claude_notify_changed`.
- Produces: a live `cc_notify` anchor item.

- [ ] **Step 1: Add the anchor block**

In `.config/sketchybar/sketchybarrc`, immediately **after** the `kanata_mode` block (after its `--subscribe kanata_mode mouse.clicked` line, before `##### Force all scripts...`), add:

```bash
##### Claude-agent notification chips #####
# Persistent "who's waiting on me" indicator. cc_notify.sh re-renders on the custom
# claude_notify_changed event (fired by the notify hook + the tmux pane-focus-in hook)
# and on focus/space changes. Hidden when nothing is pending. Left-click = dropdown
# (collapsed) ; right/alt-click = toggle expanded<->collapsed. Spec:
# docs/superpowers/specs/2026-06-24-sketchybar-claude-notify-chips-design.md
sketchybar --add event claude_notify_changed

sketchybar --add item cc_notify right \
           --set cc_notify drawing=off icon=󰂞 icon.color=0xffef9f76 \
                 popup.align=right popup.background.color=0xff292c3c \
                 popup.background.corner_radius=6 popup.background.border_width=1 \
                 popup.background.border_color=0xff51576d \
                 script="$PLUGIN_DIR/cc_notify.sh" \
                 click_script="$PLUGIN_DIR/cc_notify.sh click" \
           --subscribe cc_notify claude_notify_changed front_app_switched space_change

sketchybar --trigger claude_notify_changed   # initial paint
```

> Positioning note: this adds `cc_notify` to the right cluster. If it lands on the wrong side of the `kanata_mode` indicator, move this whole block to *before* the `kanata_mode` block (SketchyBar orders right-side items by add order). Cosmetic only.

- [ ] **Step 2: Deploy the new files into `~/.claude` / `~/.config` (if not dir-symlinked)**

The plugin sources libs from `$HOME/.claude/hooks/lib/`. Ensure the new files are reachable:

```bash
ls -l "$HOME/.claude/hooks/lib/notify-store.sh" "$HOME/.claude/hooks/lib/notify-render.sh" "$HOME/.config/sketchybar/plugins/cc_notify.sh"
```

If any is missing (individual-file symlinks rather than a dir symlink), run `./deploy.sh` (or `./setup_mac.sh`) to create them, then re-check.

- [ ] **Step 3: Reload SketchyBar + live smoke test**

```bash
sketchybar --reload
```

Then exercise it from a tmux pane:

```bash
# simulate two waiting agents in the CURRENT session's panes (replace %ids with real ones from: tmux list-panes -F '#{pane_id}')
mkdir -p ~/.cache/claude-notify/pending
printf 'notification' > ~/.cache/claude-notify/pending/$(tmux display-message -p '#{pane_id}' | tr -dc '0-9')
sketchybar --trigger claude_notify_changed
```

Expected observations:
- The `󰂞` anchor with a count appears on the bar (it was hidden before).
- **Right/alt-click** the anchor → flips between one-chip-per-agent and bell+count.
- **Left-click** (collapsed) → dropdown lists the agent(s) + a "✕ clear all" row.
- Clicking an agent → tmux jumps to that pane and the chip disappears.
- Visiting the pane by hand (then `sketchybar --trigger claude_notify_changed`) also clears it (clear-on-visit). Full automatic clear-on-visit lands with the tmux hook in Task 6.
- Closing a pane that had an entry → it disappears on the next render (prune).

- [ ] **Step 4: Commit**

```bash
git add .config/sketchybar/sketchybarrc
git commit -m "feat(sketchybar): wire cc_notify anchor item + claude_notify_changed event"
```

---

### Task 6: tmux `pane-focus-in` hook (automatic clear-on-visit)

Fire a SketchyBar refresh whenever a pane gains focus, so the entry for the pane you just opened clears immediately. `focus-events on` is already set (tmux.conf:12).

**Files:**
- Modify: `tmux/tmux.conf` (add a `set-hook` after the bell block, ~line 33)

**Interfaces:**
- Consumes: event `claude_notify_changed`.
- Produces: nothing (side effect: a refresh on pane focus).

- [ ] **Step 1: Add the hook**

In `tmux/tmux.conf`, immediately after `set-option -g bell-action any` (line 33), add:

```tmux
# Claude-agent notification chips: refresh SketchyBar when a pane gains focus, so the
# entry for the pane you just opened clears (clear-on-visit). focus-events is already on
# (above). run-shell -b so it never blocks; absolute path (tmux run-shell gets a minimal env).
set-hook -g pane-focus-in 'run-shell -b "/opt/homebrew/bin/sketchybar --trigger claude_notify_changed 2>/dev/null || true"'
```

- [ ] **Step 2: Reload tmux config**

```bash
tmux source-file ~/.tmux.conf 2>/dev/null || tmux source-file ~/.config/tmux/tmux.conf
```

(Use whichever path your deploy uses; or your prefix+r binding.)

- [ ] **Step 3: Live smoke test**

With a pending entry present (from Task 5) on pane A, switch to pane A (`Ctrl+b` then arrow / select). Expected: the chip for pane A clears automatically within a moment (no manual `--trigger` needed). Switch among panes that have/don't have entries to confirm only the visited one clears.

- [ ] **Step 4: Commit**

```bash
git add tmux/tmux.conf
git commit -m "feat(tmux): pane-focus-in triggers sketchybar notify refresh"
```

---

### Task 7: End-to-end verification + mark spec implemented

Drive the real Claude hooks and confirm the full chain, then record status.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-24-sketchybar-claude-notify-chips-design.md` (status line)

- [ ] **Step 1: Full-suite test run**

```bash
bash claude/hooks/tests/run-tests.sh
```

Expected: all `test-*.sh` pass, exit 0.

- [ ] **Step 2: Real-hook end-to-end (Notification + Stop)**

- In a tmux pane running Claude, trigger a `Notification` (e.g. a permission prompt) → confirm a `󰂞` chip appears on SketchyBar (and the existing toast + tab bell badge still fire). Tab away from that pane, let a turn finish → confirm a `󰗠` (finished) chip appears (Stop is focus-gated, so only when you weren't watching).
- Run two agents in two panes/tabs; confirm two chips, each jumping to the correct pane on click, each clearing on visit.
- Right/alt-click toggles layout; the choice persists across renders (mode file).

- [ ] **Step 3: Confirm graceful no-op outside tmux**

Run a Claude turn **outside** tmux → confirm the toast still fires and **no** chip/entry is created (`ls ~/.cache/claude-notify/pending` stays empty for that event).

- [ ] **Step 4: Update the spec status**

In `docs/superpowers/specs/2026-06-24-sketchybar-claude-notify-chips-design.md`, change:

```markdown
**Status:** Designed — not yet implemented
```

to:

```markdown
**Status:** Implemented & verified live (pending store, chips/dropdown toggle, clear-on-visit, clear-on-click, prune)
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-24-sketchybar-claude-notify-chips-design.md
git commit -m "docs(spec): mark sketchybar notify chips implemented"
```

---

## Notes for the implementer

- **Why two libs in `claude/hooks/lib/` consumed by a SketchyBar plugin:** that dir is the repo's established shell-lib home and deploys to `~/.claude/hooks/lib/`. The plugin sources them by absolute path. Keeping the store format defined once (not duplicated in the plugin) is the reason.
- **Don't touch** the existing BEL / tmux bell badge / `terminal-notifier` toast — this feature is additive. If a refactor tempts you, stop: the toast's own inline focus command is intentionally separate from the plugin's jump path.
- **`ccn_prune $live` is deliberately unquoted** — word-splitting the live pane-id list into args is the intent. The lib no-ops on zero args and the plugin also guards on a non-empty `$live`, so a failed `tmux list-panes` never wipes the store.
- **Glyphs** (`󰂞` `󰗠` `✕`) must be saved as UTF-8 exactly as written; a mangling editor will break both the lib and its test identically, but the live bar will show tofu — eyeball the bar after deploy.
