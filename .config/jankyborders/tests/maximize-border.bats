#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  mkdir -p "$HOME/.cache/yabai"
  STUB="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUB"
  # stub `borders` and `yabai` so we can detect whether they were invoked
  printf '#!/bin/sh\necho "borders $*" >> "%s/calls"\n' "$BATS_TEST_TMPDIR" > "$STUB/borders"
  printf '#!/bin/sh\necho "{\\"has-fullscreen-zoom\\":false}"\n' > "$STUB/yabai"
  chmod +x "$STUB/borders" "$STUB/yabai"
  export PATH="$STUB:$PATH"
  SCRIPT="${BATS_TEST_DIRNAME}/../maximize-border.sh"
}

@test "skips recolor while a mode guard-flag is present" {
  printf 'resize' > "$HOME/.cache/yabai/wm-mode"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TEST_TMPDIR/calls" ]   # borders never called
}

@test "recolors normally when no guard-flag" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "borders active_color" "$BATS_TEST_TMPDIR/calls"
}
