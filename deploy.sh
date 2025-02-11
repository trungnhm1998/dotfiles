#!/bin/bash
prompt_install() {
  echo -n "$1 is not installed. Would you like to install it? (y/n) " >&2
  old_stty_cfg=$(stty -g)
  stty raw -echo
  answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
  stty $old_stty_cfg && echo
  if echo "$answer" | grep -iq "^y"; then
    # This could def use community support
    if [ -x "$(command -v apt-get)" ]; then
      sudo apt-get install $1 -y
    elif [ -x "$(command -v brew)" ]; then
      brew install $1
    elif [ -x "$(command -v pkg)" ]; then
      sudo pkg install $1
    elif [ -x "$(command -v pacman)" ]; then
      sudo pacman -S $1
    else
      echo "I'm not sure what your package manager is! Please install $1 on your own and run this deploy script again. Tests for package managers are in the deploy script you just ran starting at line 13. Feel free to make a pull request at https://github.com/parth/dotfiles :)"
    fi
  fi
}

check_for_software() {
  echo "Checking to see if $1 is installed"
  if ! [ -x "$(command -v $1)" ]; then
    prompt_install $1
  else
    echo "$1 is installed."
  fi
}

check_default_shell() {
  if [ -z "${SHELL##*zsh*}" ]; then
    echo "Default shell is zsh."
  else
    echo -n "Default shell is not zsh. Do you want to chsh -s \$(which zsh)? (y/n)"
    old_stty_cfg=$(stty -g)
    stty raw -echo
    answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
    stty $old_stty_cfg && echo
    if echo "$answer" | grep -iq "^y"; then
      chsh -s $(which zsh)
    else
      echo "Warning: Your configuration won't work properly. If you exec zsh, it'll exec tmux which will exec your default shell which isn't zsh."
    fi
  fi
}

echo "We're going to do the following:"
echo "1. Check to make sure you have zsh, vim, and tmux installed"
echo "2. We'll help you install them if you don't"
echo "3. We're going to check to see if your default shell is zsh"
echo "4. We'll try to change it if it's not"

echo "Let's get started? (y/n)"
old_stty_cfg=$(stty -g)
stty raw -echo
answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
stty $old_stty_cfg
if echo "$answer" | grep -iq "^y"; then
  echo
else
  echo "Quitting, nothing was changed."
  exit 0
fi

check_for_software zsh
echo
check_for_software vim
# Install VimPlug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
echo
check_for_software tmux
# TMP
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# default tmux theme
mkdir -p ~/.config/tmux/plugins/catppuccin
git clone -b v2.1.2 https://github.com/catppuccin/tmux.git ~/.config/tmux/plugins/catppuccin/tmux
echo
check_for_software curl
echo
check_for_software wget
echo
check_for_software git
echo

ZSH_CUSTOM=~/.oh-my-zsh/custom

# Install ohmyzsh
DIRECTORY="$HOME/.oh-my-zsh"
if [ ! -d "$DIRECTORY" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# install spaceship theme
DIRECTORY="${ZSH_CUSTOM}/themes/spaceship-prompt"
if [ ! -d "$DIRECTORY" ]; then
  echo
  echo "Unable to find $DIRECTORY"
  git clone https://github.com/denysdovhan/spaceship-prompt.git $ZSH_CUSTOM/themes/spaceship-prompt
  ln -s "${ZSH_CUSTOM}/themes/spaceship-prompt/spaceship.zsh-theme" $ZSH_CUSTOM/themes/spaceship.zsh-theme
fi

# install zsh-autosuggestions
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
if [ ! -d "$DIRECTORY" ]; then
  echo
  echo "Unable to find $DIRECTORY"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# install zsh-sytanx-highlightning
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
if [ ! -d "$DIRECTORY" ]; then
  echo
  echo "Unable to find $DIRECTORY"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

# install zsh-vi-mode
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-vi-mode"
if [ ! -d "$DIRECTORY" ]; then
  echo
  echo "Unable to find $DIRECTORY"
  git clone https://github.com/jeffreytse/zsh-vi-mode ${ZSH_CUSTOM}/plugins/zsh-vi-mode
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  wget "https://github.com/sharkdp/vivid/releases/download/v0.5.0/vivid_0.5.0_amd64.deb"
  sudo dpkg -i vivid_0.5.0_amd64.deb
fi

echo
echo -n "Would you like to backup your current dotfiles? (y/n) "
old_stty_cfg=$(stty -g)
stty raw -echo
answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
stty $old_stty_cfg
if echo "$answer" | grep -iq "^y"; then
  mv ~/.zshrc ~/.zshrc.old
  mv ~/.tmux.conf ~/.tmux.conf.old
  mv ~/.vimrc ~/.vimrc.old
else
  echo -e "\nNot backing up old dotfiles."
fi

printf "source $HOME/dotfiles/zsh/zshrc_manager.sh" >~/.zshrc
printf "so $HOME/dotfiles/vim/vimrc.vim" >~/.vimrc
printf "so $HOME/dotfiles/.ideavimrc" >~/.ideavim
printf "source-file $HOME/dotfiles/tmux/tmux.conf" >~/.tmux.conf
ln -sf $HOME/dotfiles/.config/starship.toml $HOME/.config/starship.toml
ln -sf $HOME/dotfiles/.config/yazi $HOME/.config/yazi
ln -sf $HOME/dotfiles/.config/nvim $HOME/.config/nvim
ln -sf $HOME/dotfiles/.config/powershell $HOME/.config/powershell
ln -sf $HOME/dotfiles/.config/wezterm $HOME/.config/wezterm

check_default_shell

echo
echo "Please log out and log back in for default shell to be initialized."
