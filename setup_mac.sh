# install homebrew first
# maybe check for homebrew exist?
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# command lines tools
brew tap FelixKratz/formulae

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
  sketchybar

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

brew services start sketchybar
