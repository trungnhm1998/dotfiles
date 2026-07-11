#!/usr/bin/env zsh
# Zsh configuration manager - Entry point for zsh with tmux auto-attach

# --- UTF-8 locale (MUST run before the tmux attach below) ---
# tmux derives its UTF-8 mode from the client's LC_CTYPE/LANG at attach time; an SSH login
# into macOS inherits no locale -> C/POSIX -> tmux mangles glyphs/emoji. WSL2 already has
# en_US.UTF-8 (/etc/default/locale, see remote-phone/wsl/setup.sh) so the guard leaves a
# working locale untouched. Set here (not zshrc.sh) because that is sourced AFTER the attach.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
	*[Uu][Tt][Ff]8* | *[Uu][Tt][Ff]-8*) ;;          # already UTF-8 -> keep it
	*) case "$OSTYPE" in
		darwin*) export LANG=en_US.UTF-8 ;;          # always present on macOS
		*) export LANG=C.UTF-8 ;;                    # universal on glibc/musl
	esac ;;
esac

is_ide_terminal() {
	[ -n "$INTELLIJ_ENVIRONMENT_READER" ] ||
		[ -n "$VSCODE_PID" ] ||
		[ -n "$CURSOR_PID" ] ||
		[ "$TERM_PROGRAM" = "vscode" ] ||
		[ "$TERM_PROGRAM" = "cursor" ]
}

if ! is_ide_terminal; then
	# Run tmux if exists (non-fatal)
	if command -v tmux >/dev/null; then
		if [ -z "$TMUX" ]; then
			tmux attach -t main 2>/dev/null || tmux new-session -s main
		fi
  else
    echo "tmux not installed. Run ./deploy to configure dependencies"
  fi
fi

source "$HOME/dotfiles/zsh/zshrc.sh"

# bun completions
[ -s "/home/mint/.bun/_bun" ] && source "/home/mint/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
