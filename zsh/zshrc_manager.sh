is_ide_terminal() {
    [ -n "$INTELLIJ_ENVIRONMENT_READER" ] || \
    [ -n "$VSCODE_PID" ] || \
    [ -n "$CURSOR_PID" ] || \
    [ "$TERM_PROGRAM" = "vscode" ] || \
    [ "$TERM_PROGRAM" = "cursor" ]
}

if ! is_ide_terminal; then
  time_out() { perl -e 'alarm shift; exec @ARGV' "$@"; }

  # Run tmux if exists
  if command -v tmux >/dev/null; then
    [ -z $TMUX ] && exec tmux
  else
    echo "tmux not installed. Run ./deploy to configure dependencies"
  fi

  echo "Updating configuration"
fi
# (cd ~/dotfiles && time_out 3 git pull && time_out 3 git submodule update --init --recursive)
# (cd ~/dotfiles && git pull && git submodule update --init --recursive)
source ~/dotfiles/zsh/zshrc.sh
