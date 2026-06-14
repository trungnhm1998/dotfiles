#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget one-tap connect to the WSL dev box over Tailscale + Mosh.
#
# Install:
#   mkdir -p ~/.shortcuts
#   cp connect-claude.sh ~/.shortcuts/connect-claude
#   chmod +x ~/.shortcuts/connect-claude
# Then add the Termux:Widget to your home screen and tap "connect-claude".
#
# Requires the phone's Tailscale VPN to be ON. The WSL zsh login auto-attaches
# the persistent "main" tmux session.

exec mosh mint@100.107.134.26
# Alternative if MagicDNS resolves in Termux:  exec mosh mint@max-wsl
