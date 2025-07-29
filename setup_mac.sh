#!/bin/zsh
xcode-select --install
# install homebrew first
# maybe check for homebrew exist?
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# taps
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae

# command lines tools
brew install \
  neovim \
  node \
  universal-ctags \
  lua-language-server \
  stylua \
  ripgrep \
  pandoc \
  fzf \
  ffmpeg \
  fontconfig \
  hugo \
  miniconda \
  tmux \
  jq \
  fd \
  wget \
  poppler \
  eza \
  lazygit \
  yazi \
  font-fira-cod \
  starship \
  nvm \
  btop \
  1password-cli \
  gawk \
  pyenv \
  tldr \
  sketchybar \
  svim \
  zoxide \
  gh \
  skhd \
  borders \
  yabai \
  bat

# HomeBrew casks
brew install --cask \
  skim \
  calibre \
  keycastr \
  wezterm \
  kitty \
  miniconda \
  homebrew/cask-fonts \
  alt-tab \
  sketchybar \
  font-sketchybar-app-font \
  sf-symbols # for sketchybar
  font-sf-mono \
  font-sf-pro \
  font-hack-nerd-font \
  font-jetbrains-mono \
  font-fira-code

ln -sf $HOME/dotfiles/.config/yabai $HOME/.config/yabai
ln -sf $HOME/dotfiles/.config/skhd $HOME/.config/skhd
ln -sf $HOME/dotfiles/.config/jankyborders $HOME/.config/jankyborders
ln -sf $HOME/dotfiles/.config/sketchybar $HOME/.config/sketchybar
ln -s $(which sketchybar) $(dirname $(which sketchybar))/external_bar # to use multiple bars
ln -sf $HOME/dotfiles/.config/external_bar $HOME/.config/external_bar
ln -sf $HOME/dotfiles/.config/svim $HOME/.config/svim

brew services start svim
brew services start sketchybar

