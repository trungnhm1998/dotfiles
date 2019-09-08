export ZSH=$HOME/.oh-my-zsh
export JAVA_HOME="/media/trung/OS/dev-tools/jdk1.8.0_202"
export ANDROID_HOME="/media/trung/OS/dev-tools/sdk"
export PATH=$PATH:$JAVA_HOME
export PATH=$PATH:$JAVA_HOME/bin
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$HOME/bin:usr/local/bin:$PATH
export PATH=$HOME/.local/share/umake/bin:$PATH
export PATH=$PATH:/usr/local/nodejs/bin
export TERM=xterm-256color
export TERMINAL="terminator"
export VISUAL=vim
export EDITOR="$VISUAL"
export LS_COLORS=$LS_COLORS:"$(vivid generate snazzy)"
export LS_COLORS=$LS_COLORS:"tw=30;42:ow=30;42"

ZSH_THEME="spaceship"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

alias tmux="TERM=screen-256color-bce tmux"
alias code="code --disable-gpu"

source $ZSH/oh-my-zsh.sh
source ~/dotfiles/zsh/keybindings.sh
