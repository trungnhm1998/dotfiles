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

# jump command: focuses the session + the pane (by id) and raises WezTerm
jc="$(ccn_jump_cmd 'work' '%7')"
assert_contains "$jc" "switch-client -t 'work'" "jump cmd switches to the session"
assert_contains "$jc" "select-window -t '%7'"   "jump cmd selects the window by pane id"
assert_contains "$jc" "select-pane -t '%7'"     "jump cmd selects the pane"
assert_contains "$jc" "open -b com.github.wez.wezterm" "jump cmd raises WezTerm"

finish
