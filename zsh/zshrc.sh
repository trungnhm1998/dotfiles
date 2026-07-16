#!/usr/bin/env zsh
# Main zsh configuration file
typeset -U path PATH  # auto-dedupe PATH entries (idempotent across re-sources)
[[ -d /opt/nvim-linux-x86_64/bin ]] && export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
# Android SDK platform-tools (macOS only)
if [[ "$OSTYPE" == "darwin"* ]] && [[ -d "$HOME/Library/Android/sdk/platform-tools" ]]; then
	export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
fi
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH=$HOME/.local/share/umake/bin:$PATH
export PATH=$PATH:/usr/local/nodejs/bin
export PATH="$HOME/.local/bin:$PATH"

# --- pyenv (Python version manager; shared mac + Linux) ---
# Guarded so a machine without pyenv installed sources cleanly. We prepend the
# Linux pyenv's own bin BEFORE calling `pyenv init` so on WSL2 a Windows-PATH
# pyenv-win shim can't win (see deploy.sh's WSL2 note). `pyenv init - zsh`
# prepends $PYENV_ROOT/shims, so `python`/`python3`/`python2` resolve to shims.
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ] && [ -x "$PYENV_ROOT/bin/pyenv" ]; then
	export PATH="$PYENV_ROOT/bin:$PATH"
	eval "$(pyenv init - zsh)"
fi

export VISUAL=nvim
export EDITOR="$VISUAL"
export XDG_CONFIG_HOME="$HOME/.config"
# Don't set TERM here. The host owns it: WezTerm exports xterm-256color outside tmux,
# tmux sets tmux-256color inside. Exporting xterm-256color unconditionally re-clobbered
# the inner tmux shell, breaking italics/undercurl capability detection. COLORTERM still
# advertises truecolor to apps that sniff it (which is how truecolor survives in tmux).
export COLORTERM=truecolor
# Claude Code caps its TUI to 256-color whenever $TMUX is set (regression since 2.1.77), muting
# Clawd/the "Thinking" spinner even though tmux forwards truecolor fine to every other app. This
# escape hatch skips that clamp while keeping $TMUX set, so tmux-awareness (notification
# passthrough) stays intact -- unlike `env -u TMUX claude`. Needs Claude Code >= 2.1.83.
export CLAUDE_CODE_TMUX_TRUECOLOR=1

# --- secrets (gitignored; see secrets.env.example) ---
[ -f "$HOME/.config/dotfiles/secrets.env" ] && source "$HOME/.config/dotfiles/secrets.env"

# install https://github.com/sharkdp/vivid/releases for using vivid below
if [ -x "$(command -v vivid)" ]; then
	export LS_COLORS=$LS_COLORS:"$(vivid generate catppuccin-frappe)"
	export LS_COLORS=$LS_COLORS:"tw=30;42:ow=30;42"
fi

# nvm
export NVM_DIR="$HOME/.nvm"
# nvm.sh + completion are loaded once by the oh-my-zsh `nvm` plugin (plugins+=(nvm) below).
# Don't source them here too — nvm is the biggest zsh startup cost and this paid it twice.

# --- yazi cd to directory after exit ---
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# --- claude-squad (cs): make Ctrl+Q detach work ---
# cs detaches by reading ONE raw Ctrl+Q byte (0x11). Our tmux `extended-keys on`
# (added for Claude Code's Shift+Enter) rewrites Ctrl+Q into a CSI-u sequence
# (ESC[27;5;113~), which cs's `buf[0]==17` check can't recognise — so Ctrl+Q never
# detaches and the session gets killed instead. Flip the server option off for the
# lifetime of the cs TUI, then restore it. `command tmux` skips the omz tmux-plugin
# wrapper; `command cs` calls the binary, not this function.
# ponytail: server-wide + restore-on-exit. If cs is SIGKILLed mid-run, extkeys stays
#           off — just rerun cs or `tmux set -s extended-keys on`.
cs() {
	if [ -n "$TMUX" ]; then
		command tmux set -s extended-keys off
		{
			command cs "$@"
		} always {
			command tmux set -s extended-keys on  # restore even on Ctrl+C / error / nonzero exit
		}
	else
		command cs "$@"
	fi
}

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
	vi-mode
	tmux
    sudo
    colored-man-pages
    history-substring-search
    npm
    aws
    extract
    aliases
)

source "$ZSH/oh-my-zsh.sh"
command -v starship >/dev/null && eval "$(starship init zsh)"
source "$HOME/dotfiles/zsh/keybindings.sh"

# ---- FZF ----
# Set up fzf key bindings and fuzzy completion
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"
command -v fzf >/dev/null && source <(fzf --zsh)

# Catppuccin Frappe theme
export FZF_DEFAULT_OPTS=" \
--color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 \
--color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
--color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
--color=selected-bg:#51576D \
--color=border:#737994,label:#C6D0F5 \
--height 50% \
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
# --cmd cd replaces `cd` with zoxide (and adds `cdi` for interactive fzf jumps).
# Must run after compinit (oh-my-zsh.sh above) so completions register correctly.
# _ZO_DOCTOR=0: silence zoxide's "possible configuration issue" doctor. It false-positives
# in non-interactive subprocess shells (e.g. tools that source this file) — see
# https://github.com/ajeetdsouza/zoxide/issues/1208 — even though placement here is correct
# (__zoxide_hook is the sole chpwd hook). The check has nothing useful left to report.
export _ZO_DOCTOR=0
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# --- eza --- (guard so missing eza doesn't shadow/break core ls/ll/la)
if command -v eza >/dev/null 2>&1; then
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
fi

# eval $(thefuck --alias)

# --- Claude Code, routed through the local proxy on :8080 ---
# Launch claude in a subshell with ANTHROPIC_BASE_URL pointed at the local proxy; the parent
# shell's ANTHROPIC_BASE_URL (e.g. ccflare) is left untouched. NOTE: shadows the `cc` C-compiler
# in interactive shells only -- build tools exec `cc` via PATH so they're unaffected; run
# `command cc` for the compiler.
cc() { ( export ANTHROPIC_BASE_URL="http://localhost:8080"; exec claude "$@" ) }

# --- worktree local-file seeding (see dotfiles scripts/worktree-seed.sh) ---
# Copy local-only files (.worktreeinclude manifest) from the main worktree into a fresh
# one. `wt-seed <path>` seeds one worktree; `wt-seed-all` re-pushes to every worktree.
wt-seed()     { bash "$HOME/dotfiles/scripts/worktree-seed.sh" "$@"; }
wt-seed-all() { bash "$HOME/dotfiles/scripts/worktree-seed.sh" --all; }
