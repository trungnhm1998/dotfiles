#!/usr/bin/env bats

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../wm-toggle.sh"
  export WM_TOGGLE_NOEXEC=1          # source-only: define funcs, run nothing
  source "$SCRIPT"
}

@test "decides stop when running, start when stopped" {
  [ "$(wm_decide 1)" = "stop" ]
  [ "$(wm_decide 0)" = "start" ]
}

@test "glyph differs by state" {
  run wm_glyph 1; work="$output"
  run wm_glyph 0; game="$output"
  [ -n "$work" ] && [ -n "$game" ] && [ "$work" != "$game" ]
}
