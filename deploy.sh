#!/bin/bash
prompt_install() {
	echo -n "$1 is not installed. Would you like to install it? (y/n) " >&2
	old_stty_cfg=$(stty -g)
	stty raw -echo
	answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
	stty "$old_stty_cfg" && echo
	if echo "$answer" | grep -iq "^y"; then
		# This could def use community support
		if [ -x "$(command -v apt-get)" ]; then
			sudo apt-get install "$1" -y
		elif [ -x "$(command -v brew)" ]; then
			brew install "$1"
		elif [ -x "$(command -v pkg)" ]; then
			sudo pkg install "$1"
		elif [ -x "$(command -v pacman)" ]; then
			sudo pacman -S "$1"
		else
			echo "I'm not sure what your package manager is! Please install $1 on your own and run this deploy script again. Tests for package managers are in the deploy script you just ran starting at line 13. Feel free to make a pull request at https://github.com/parth/dotfiles :)"
		fi
	fi
}

check_for_software() {
	echo "Checking to see if $1 is installed"
	if ! [ -x "$(command -v "$1")" ]; then
		prompt_install "$1"
	else
		echo "$1 is installed."
	fi
}

# Install software with package manager-specific package names
# Usage: install_package <command_name> <apt_pkg> <brew_pkg> <pacman_pkg> [custom_installer_func]
# Use "-" or "0" as package name to skip that package manager (will fall through to custom installer)
install_package() {
	local cmd_name="$1"
	local apt_pkg="$2"
	local brew_pkg="$3"
	local pacman_pkg="$4"
	local custom_installer="$5"

	echo "Checking to see if $cmd_name is installed"
	if [ -x "$(command -v "$cmd_name")" ]; then
		echo "$cmd_name is installed."
		return
	fi

	echo -n "$cmd_name is not installed. Would you like to install it? (y/n) " >&2
	old_stty_cfg=$(stty -g)
	stty raw -echo
	answer=$(while ! head -c 1 | grep -i '[ny]'; do true; done)
	stty "$old_stty_cfg" && echo

	if echo "$answer" | grep -iq "^y"; then
		local installed=false

		if [ -x "$(command -v apt-get)" ] && [ "$apt_pkg" != "-" ] && [ "$apt_pkg" != "0" ]; then
			sudo apt-get install "$apt_pkg" -y
			installed=true
		elif [ -x "$(command -v brew)" ] && [ "$brew_pkg" != "-" ] && [ "$brew_pkg" != "0" ]; then
			brew install "$brew_pkg"
			installed=true
		elif [ -x "$(command -v pkg)" ] && [ "$brew_pkg" != "-" ] && [ "$brew_pkg" != "0" ]; then
			sudo pkg install "$brew_pkg" # FreeBSD pkg often uses same names as brew
			installed=true
		elif [ -x "$(command -v pacman)" ] && [ "$pacman_pkg" != "-" ] && [ "$pacman_pkg" != "0" ]; then
			sudo pacman -S "$pacman_pkg"
			installed=true
		fi

		# If no package manager handled it and we have a custom installer, use it
		if [ "$installed" = false ] && [ -n "$custom_installer" ]; then
			$custom_installer
		elif [ "$installed" = false ]; then
			echo "I'm not sure what your package manager is! Please install $cmd_name on your own."
		fi
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
		stty "$old_stty_cfg" && echo
		if echo "$answer" | grep -iq "^y"; then
			chsh -s "$(which zsh)"
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
stty "$old_stty_cfg"
if echo "$answer" | grep -iq "^y"; then
	echo
else
	echo "Quitting, nothing was changed."
	exit 0
fi

# Detect WSL2 and warn about Windows PATH pollution
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo
    echo "========================================="
    echo "⚠️  WSL2 Environment Detected"
    echo "========================================="
    echo "Windows programs in your PATH may cause conflicts."
    echo ""
    echo "Common issues:"
    echo "  • pyenv-win instead of Linux pyenv"
    echo "  • Windows commands executed instead of Linux versions"
    echo ""
    echo "This script will install Linux versions of all tools."
    echo "The zsh configuration includes guards to prevent conflicts."
    echo "========================================="
    echo
fi

check_for_software zsh
echo
check_for_software vim
# Install VimPlug
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
	echo "Installing VimPlug..."
	curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || echo "Failed to install VimPlug"
fi
echo
check_for_software tmux
# TPM
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
	echo "Installing TPM (Tmux Plugin Manager)..."
	git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || echo "Failed to install TPM"
fi
if [ ! -d "$HOME/fzf-git" ]; then
	echo "Installing fzf-git.sh..."
	git clone --depth 1 https://github.com/junegunn/fzf-git.sh "$HOME/fzf-git" || echo "Failed to install fzf-git"
fi
# default tmux theme
if [ ! -d "$HOME/.config/tmux/plugins/catppuccin" ]; then
	echo "Installing catppuccin tmux theme..."
	mkdir -p "$HOME/.config/tmux/plugins/catppuccin"
	git clone -b v2.1.2 https://github.com/catppuccin/tmux.git "$HOME/.config/tmux/plugins/catppuccin/tmux" || echo "Failed to install catppuccin theme"
fi
echo
check_for_software curl
echo
check_for_software wget
echo
check_for_software git
echo
check_for_software bat
mkdir -p "$HOME/.local/bin"
ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
mkdir -p "$(bat --config-dir)/themes"
wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Latte.tmTheme
wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Frappe.tmTheme
wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Macchiato.tmTheme
wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme
bat cache --build
echo

# Packages with different names across package managers
# install_package <command> <apt_pkg> <brew_pkg> <pacman_pkg>
install_package ffmpeg ffmpeg ffmpeg ffmpeg
echo
install_package 7z p7zip-full p7zip p7zip
echo
install_package jq jq jq jq
echo
install_package pdftotext poppler-utils poppler poppler
echo
install_package fd fd-find fd fd
# Create fd symlink if fdfind exists (Ubuntu package name is fd-find)
if [ -x "$(command -v fdfind)" ] && [ ! -x "$(command -v fd)" ]; then
    echo "Creating fd symlink for fdfind..."
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi
echo
install_package rg ripgrep ripgrep ripgrep
echo
# fzf: Install via git clone on apt systems for latest version with better integration
install_fzf_git() {
	if [ ! -d "$HOME/.fzf" ]; then
		echo "Installing fzf via git..."
		git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
		"$HOME/.fzf/install" --all
	else
		echo "fzf directory exists, running install script..."
		"$HOME/.fzf/install" --all
	fi
}
install_package fzf - fzf fzf install_fzf_git
echo
install_package zoxide zoxide zoxide zoxide
echo
install_package magick imagemagick imagemagick imagemagick
echo
# starship: Install via official installer for system-wide installation (works on macOS and Linux)
install_starship_curl() {
	echo "Installing starship via official installer (system-wide to /usr/local/bin)..."
	curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir /usr/local/bin --yes
}
install_package starship - - - install_starship_curl
echo
install_package eza eza eza eza
echo
install_package yazi - - yazi
echo

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

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
	git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
	ln -s "${ZSH_CUSTOM}/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# install zsh-autosuggestions
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
if [ ! -d "$DIRECTORY" ]; then
	echo
	echo "Unable to find $DIRECTORY"
	git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
fi

# install zsh-syntax-highlighting
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
if [ ! -d "$DIRECTORY" ]; then
	echo
	echo "Unable to find $DIRECTORY"
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
fi

# install zsh-vi-mode
DIRECTORY="${ZSH_CUSTOM}/plugins/zsh-vi-mode"
if [ ! -d "$DIRECTORY" ]; then
	echo
	echo "Unable to find $DIRECTORY"
	git clone https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode"
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
stty "$old_stty_cfg"
if echo "$answer" | grep -iq "^y"; then
	mv "$HOME/.zshrc" "$HOME/.zshrc.old"
	mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.old"
	mv "$HOME/.vimrc" "$HOME/.vimrc.old"
else
	echo -e "\nNot backing up old dotfiles."
fi

ln -sf "$HOME/dotfiles/zsh/zshrc_manager.sh" "$HOME/.zshrc"
ln -sf "$HOME/dotfiles/vim/vimrc.vim" "$HOME/.vimrc"
ln -sf "$HOME/dotfiles/.ideavimrc" "$HOME/.ideavimrc"
ln -sf "$HOME/dotfiles/tmux/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$HOME/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml"
ln -sf "$HOME/dotfiles/.config/yazi" "$HOME/.config/yazi"
ln -sf "$HOME/dotfiles/.config/nvim" "$HOME/.config/nvim"
ln -sf "$HOME/dotfiles/.config/powershell" "$HOME/.config/powershell"
ln -sf "$HOME/dotfiles/.config/wezterm" "$HOME/.config/wezterm"
ln -sf "$HOME/dotfiles/.config/bat/config" "$HOME/.config/bat/config"

check_default_shell

echo
echo "Please log out and log back in for default shell to be initialized."
