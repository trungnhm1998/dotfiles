#!/usr/bin/env bash
# fix-tui.sh - repair a garbled terminal on Unix.
#
# NOT a port of fix-claude-tui.ps1. Read this before expecting it to be one.
#
# The Windows bug that script repairs is a wrong *console code page* - a property of a
# kernel object shared by every process attached to the console, which is why an outside
# process can reach in and correct it for a running program.
#
# Unix has no such object. A terminal's character encoding comes from the per-process locale
# (LC_ALL / LC_CTYPE / LANG) inherited at exec time, and there is no supported way to change
# another running process's environment. So the Windows failure mode cannot occur here, and
# the Windows repair has no equivalent here. Two different bugs.
#
# What DOES garble a Unix terminal, and what this fixes:
#   1. Charset state corruption - dumping a binary (cat a.out, a truncated curl) emits SO
#      (0x0E) or ESC ( 0, switching the terminal to the line-drawing charset. Every letter
#      then renders as a box glyph. Cosmetic, sticky, fixed by resetting charset state.
#   2. A locale that is not UTF-8 - then mojibake is correct behaviour and no escape sequence
#      helps; the fix is to export a UTF-8 locale and RESTART the program. Reported, not
#      "fixed", because it cannot be fixed from outside.
#
# Usage:
#   fix-tui.sh          reset charset state, keep scrollback, report locale
#   fix-tui.sh --hard   full terminal reset (RIS) - clears scrollback
set -euo pipefail

hard=0
[ "${1:-}" = "--hard" ] && hard=1

if [ "$hard" -eq 1 ]; then
  # RIS: full reset. Nukes scrollback, fixes states a soft reset will not.
  printf '\033c'
else
  printf '\033(B'   # G0 = US ASCII (undo ESC ( 0 line-drawing)
  printf '\017'     # SI: shift back to G0 (undo SO)
  printf '\033%%G'  # select UTF-8 character set
  printf '\033[!p'  # DECSTR: soft terminal reset, leaves scrollback intact
fi

# Locale is the other half, and the half no escape sequence can repair.
enc=$(locale charmap 2>/dev/null || echo unknown)
case "$enc" in
  UTF-8|utf8|UTF8) : ;;
  *)
    printf '\n' >&2
    echo "warning: locale charmap is '$enc', not UTF-8." >&2
    echo "  Escape sequences cannot fix this - UTF-8 output will keep rendering as mojibake." >&2
    echo "  Export a UTF-8 locale and restart the affected program, e.g.:" >&2
    echo "      export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8" >&2
    echo "  Current: LC_ALL='${LC_ALL:-}' LC_CTYPE='${LC_CTYPE:-}' LANG='${LANG:-}'" >&2
    exit 1
    ;;
esac
