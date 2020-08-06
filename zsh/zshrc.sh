export ZSH=$HOME/.oh-my-zsh
export ZSH_CUSTOM=$HOME/.oh-my-zsh/custom
export PATH=$HOME/bin:usr/local/bin:$PATH
export PATH=$HOME/.local/share/umake/bin:$PATH
export PATH=$PATH:/usr/local/nodejs/bin
export ANDROID_HOME=/Users/iosteam/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
export TERM=xterm-256color
export VISUAL=vim
export EDITOR="$VISUAL"
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
# install https://github.com/sharkdp/vivid/releases for using vivid below
if [ -x "$(command -v vivid)" ]; then
  export LS_COLORS=$LS_COLORS:"$(vivid generate snazzy)"
  export LS_COLORS=$LS_COLORS:"tw=30;42:ow=30;42"
fi

ZSH_THEME="spaceship"
ZSH_DISABLE_COMPFIX=true

plugins=(
  nvm
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

#alias tmux="TERM=screen-256color-bce tmux"

source $ZSH/oh-my-zsh.sh
source ~/dotfiles/zsh/keybindings.sh
