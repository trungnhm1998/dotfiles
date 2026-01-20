#!/usr/bin/env zsh
# Zsh configuration manager - Entry point for zsh with tmux auto-attach
is_ide_terminal() {
	[ -n "$INTELLIJ_ENVIRONMENT_READER" ] ||
		[ -n "$VSCODE_PID" ] ||
		[ -n "$CURSOR_PID" ] ||
		[ "$TERM_PROGRAM" = "vscode" ] ||
		[ "$TERM_PROGRAM" = "cursor" ]
}

if ! is_ide_terminal; then
	time_out() { perl -e 'alarm shift; exec @ARGV' "$@"; }

	# Run tmux if exists (non-fatal)
	if command -v tmux >/dev/null; then
		if [ -z "$TMUX" ]; then
			tmux attach 2>/dev/null || tmux new-session
		fi
  else
    echo "tmux not installed. Run ./deploy to configure dependencies"
  fi
fi

source "$HOME/dotfiles/zsh/zshrc.sh"
