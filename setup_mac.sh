#!/bin/zsh
# install homebrew first
# Run: xcode-select --install (before running this script)
# maybe check for homebrew exist?
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# taps
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae
brew tap deskflow/tap

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
    ffmpeg \
    sevenzip \
    resvg \
    imagemagick \
    font-symbols-only-nerd-font \
    yazi \
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
    bat \
    deskflow

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
    sf-symbols \
    font-sf-mono \
    font-sf-pro \
    font-hack-nerd-font \
    font-jetbrains-mono \
    font-fira-code \
    karabiner-elements

ln -sf $HOME/dotfiles/.config/yabai $HOME/.config/yabai
ln -sf $HOME/dotfiles/.config/skhd $HOME/.config/skhd
ln -sf $HOME/dotfiles/.config/jankyborders $HOME/.config/jankyborders
ln -sf $HOME/dotfiles/.config/sketchybar $HOME/.config/sketchybar
ln -s $(which sketchybar) $(dirname $(which sketchybar))/external_bar # to use multiple bars
ln -sf $HOME/dotfiles/.config/external_bar $HOME/.config/external_bar
ln -sf $HOME/dotfiles/.config/svim $HOME/.config/svim

brew services start svim
brew services start sketchybar

defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 1
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false              # For VS Code
defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false     # For Cursor
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false      # For VS Code Insider
defaults write com.vscodium ApplePressAndHoldEnabled -bool false                      # For VS Codium
defaults write com.microsoft.VSCodeExploration ApplePressAndHoldEnabled -bool false   # For VS Codium Exploration users
defaults write com.exafunction.windsurf ApplePressAndHoldEnabled -bool false          # For Windsurf
