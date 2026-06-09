#!/bin/bash
# Copy the canonical global agent instructions (claude/AGENTS.md) to the clipboard so you
# can paste them into Cursor -> Settings -> Rules -> User Rules. Cursor has no global rules
# file to symlink (User Rules live in its synced settings DB), so this is the supported way
# to give Cursor the same instructions the CLI agents get. Re-run after editing AGENTS.md.
#
# Works on macOS (pbcopy), Wayland (wl-copy), X11 (xclip/xsel), and Windows-with-bash
# (clip.exe). On native PowerShell, instead run:
#   Get-Content $HOME\.claude\AGENTS.md -Raw | Set-Clipboard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(dirname "$SCRIPT_DIR")"
AGENTS="$DOTFILES/claude/AGENTS.md"

if [ ! -f "$AGENTS" ]; then
	echo "Not found: $AGENTS" >&2
	exit 1
fi

if command -v pbcopy >/dev/null 2>&1; then
	pbcopy <"$AGENTS"
elif command -v wl-copy >/dev/null 2>&1; then
	wl-copy <"$AGENTS"
elif command -v xclip >/dev/null 2>&1; then
	xclip -selection clipboard <"$AGENTS"
elif command -v xsel >/dev/null 2>&1; then
	xsel --clipboard --input <"$AGENTS"
elif command -v clip.exe >/dev/null 2>&1; then
	clip.exe <"$AGENTS"
else
	echo "No clipboard tool found (tried pbcopy, wl-copy, xclip, xsel, clip.exe)." >&2
	echo "Copy it manually from: $AGENTS" >&2
	exit 1
fi

echo "Copied claude/AGENTS.md to the clipboard."
echo "Paste into Cursor -> Settings -> Rules -> User Rules."
