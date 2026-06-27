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
    terminal-notifier \
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
    zoxide \
    gh \
    skhd \
    borders \
    yabai \
    bat \
    kanata \
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
    hammerspoon

ln -sf $HOME/dotfiles/.config/yabai $HOME/.config/yabai
# Hammerspoon is the sole hotkey daemon (skhd retired — binary kept, service stopped)
ln -sf "$HOME/dotfiles/.config/hammerspoon" "$HOME/.hammerspoon"
skhd --stop-service 2>/dev/null || true
echo "⚠️  Grant Hammerspoon Accessibility permission: System Settings → Privacy & Security → Accessibility (one-time)."
ln -sf $HOME/dotfiles/.config/jankyborders $HOME/.config/jankyborders
ln -sf $HOME/dotfiles/.config/sketchybar $HOME/.config/sketchybar
ln -s $(which sketchybar) $(dirname $(which sketchybar))/external_bar # to use multiple bars
ln -sf $HOME/dotfiles/.config/external_bar $HOME/.config/external_bar
ln -sf $HOME/dotfiles/.config/kanata $HOME/.config/kanata
# svim — disabled 2026-06-20 (unused). To re-enable: add "svim" back to the brew
# install list above, then uncomment this symlink and the "brew services start svim" below.
# ln -sf $HOME/dotfiles/.config/svim $HOME/.config/svim

# AI tool configs (Claude Code + opencode) — shared with deploy.sh
bash "$HOME/dotfiles/scripts/sync-ai-configs.sh"

# Pre-warm the Claude-notify WezTerm toast icon (-contentImage thumbnail). The hook
# self-heals if this is skipped/missing; this just avoids paying generation on the
# first notification. Needs WezTerm (cask above) + sips (built-in).
bash -c 'source "$HOME/dotfiles/claude/hooks/lib/notify-lib.sh"; _cc_wezterm_icon >/dev/null' 2>/dev/null \
    && echo "Claude-notify WezTerm toast icon cached." || true

# brew services start svim   # disabled — see svim note above
brew services start sketchybar

# --- kanata keyboard remapper (built-in keyboard only) ---
# One-time manual setup (the driver needs GUI approval, so it can't be scripted):
#   1. Install Karabiner-DriverKit-VirtualHIDDevice v6.2.0 (pinned in kanata's setup-macos.md):
#        https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/tag/v6.2.0
#   2. Activate the driver extension. NOTE: the Manager app is HIDDEN (leading dot):
#        sudo "/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" forceActivate
#      then enable it: System Settings > General > Login Items & Extensions > Driver Extensions
#      > org.pqrs.Karabiner-DriverKit-VirtualHIDDevice. Grant kanata Input Monitoring + Accessibility.
#   3. Install + load BOTH root LaunchDaemons:
#      (a) pqrs VirtualHIDDevice daemon — REQUIRED. kanata connects to this; without it kanata
#          errors "Karabiner-VirtualHIDDevice driver is not activated". Karabiner-Elements used to
#          run it implicitly, so this was easy to miss until KE was uninstalled.
#        sudo cp ~/.config/kanata/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist /Library/LaunchDaemons/
#        sudo chown root:wheel /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist
#        sudo launchctl bootstrap system /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist
#      (b) kanata itself:
#        sudo cp ~/.config/kanata/dev.kanata.kanata.plist /Library/LaunchDaemons/dev.kanata.kanata.plist
#        sudo sed -i '' "s|__KANATA__|$(which kanata)|; s|__USER__|$USER|" /Library/LaunchDaemons/dev.kanata.kanata.plist
#        sudo chown root:wheel /Library/LaunchDaemons/dev.kanata.kanata.plist
#        sudo launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist
# Reload after editing kanata.kbd: scripts/kanata-reload.sh
echo "NOTE: kanata installed — finish the one-time driver + daemon setup (see README 'Keyboard Remapping (Kanata)')."

# --- kanata layer indicator (WORK/GAME toast + SketchyBar) ---
# Needs --port in dev.kanata.kanata.plist (already included). One-time USER agent:
#   mkdir -p ~/.cache/kanata
#   cp ~/.config/kanata/dev.kanata.layer-listener.plist ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
#   sed -i '' "s|__USER__|$USER|" ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
#   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
# Reload after editing the listener: launchctl bootout gui/$(id -u)/dev.kanata.layer-listener && \
#   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kanata.layer-listener.plist

defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 1
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false              # For VS Code
defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false     # For Cursor
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false      # For VS Code Insider
defaults write com.vscodium ApplePressAndHoldEnabled -bool false                      # For VS Codium
defaults write com.microsoft.VSCodeExploration ApplePressAndHoldEnabled -bool false   # For VS Codium Exploration users
defaults write com.exafunction.windsurf ApplePressAndHoldEnabled -bool false          # For Windsurf
