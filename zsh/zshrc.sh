#!/usr/bin/env zsh
# Main zsh configuration file
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
# Android SDK platform-tools (macOS only)
if [[ "$OSTYPE" == "darwin"* ]] && [[ -d "$HOME/Library/Android/sdk/platform-tools" ]]; then
	export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
fi
export PATH=$HOME/bin:usr/local/bin:$PATH
export PATH=$HOME/.local/share/umake/bin:$PATH
export PATH=$PATH:/usr/local/nodejs/bin
export PATH="$HOME/.local/bin:$PATH"
export VISUAL=nvim
export EDITOR="$VISUAL"

# install https://github.com/sharkdp/vivid/releases for using vivid below
if [ -x "$(command -v vivid)" ]; then
	export LS_COLORS=$LS_COLORS:"$(vivid generate snazzy)"
	export LS_COLORS=$LS_COLORS:"tw=30;42:ow=30;42"
fi

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# --- pyenv ---
# Skip if pyenv is a Windows executable (WSL2 PATH pollution)
if command -v pyenv >/dev/null 2>&1; then
    pyenv_path=$(command -v pyenv)
    # Skip if pyenv is in /mnt/c (Windows drive in WSL)
    if [[ "$pyenv_path" != /mnt/c* ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init --path)"
    fi
fi

# --- ruby env ---
# export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
# export PATH=$HOME/.gem/ruby/2.6.0/bin:$PATH
# if which rbenv >/dev/null; then eval "$(rbenv init -)"; fi

# export GEM_HOME="$(ruby -e 'puts Gem.user_dir')"
# export PATH="$PATH:$GEM_HOME/bin"

# --- yazi cd to directory after exit ---
# function y() {
# 	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
# 	yazi "$@" --cwd-file="$tmp"
# 	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
# 		builtin cd -- "$cwd"
# 	fi
# 	rm -f -- "$tmp"
# }

# --- zsh and oh-my-zsh ---

export ZSH=$HOME/.oh-my-zsh
export ZSH_CUSTOM=$HOME/.oh-my-zsh/custom

# ZSH_THEME="spaceship"
ZSH_DISABLE_COMPFIX=true

plugins+=(
	nvm
	git
	zsh-autosuggestions
	zsh-syntax-highlighting
	pyenv
	vi-mode
	tmux
)

source "$ZSH/oh-my-zsh.sh"
eval "$(starship init zsh)"
source "$HOME/dotfiles/zsh/keybindings.sh"

# ---- FZF ----
# Set up fzf key bindings and fuzzy completion
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"
source <(fzf --zsh)

# Catppuccin Frappe theme
export FZF_DEFAULT_OPTS=" \
--color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 \
--color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
--color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
--color=selected-bg:#51576D \
--color=border:#737994,label:#C6D0F5 \
--height 50%
--layout reverse --border top \
--inline-info \
--tmux center" # Open in tmux popup if on tmux, otherwise use --height mode


# Preview file content using bat (https://github.com/sharkdp/bat)
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# CTRL-Y to copy the command into clipboard using pbcopy
export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

# brew install tree
# Print tree structure in the preview window
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

[ -f "$HOME/fzf-git/fzf-git.sh" ] && source "$HOME/fzf-git/fzf-git.sh"

# --- zoxide ---
eval "$(zoxide init zsh)"
alias cd='z'

# --- eza ---
alias ls="eza --icons"
alias l="eza --icons"
alias ll="eza -lg --icons"
alias la="eza -lag --icons"
alias lt="eza -lTg --icons"
alias lt1="eza -lTg --level=1 --icons"
alias lt2="eza -lTg --level=2 --icons"
alias lt3="eza -lTg --level=3 --icons"
alias lta="eza -lTag --icons"
alias lta1="eza -lTag --level=1 --icons"
alias lta2="eza -lTag --level=2 --icons"
alias lta3="eza -lTag --level=3 --icons"

# eval $(thefuck --alias)
