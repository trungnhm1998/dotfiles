#!/usr/bin/env bash
# One-time WSL2 (Ubuntu) provisioning for phone access via Tailscale + Mosh + tmux.
# Run inside WSL:  bash remote-phone/wsl/setup.sh
set -euo pipefail

echo "==> Packages: mosh, locales, openssh-server"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mosh locales openssh-server

echo "==> Generate UTF-8 locale (required by mosh-server)"
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

echo "==> Enable SSH service"
sudo ssh-keygen -A
sudo install -d -m 0755 /run/sshd
sudo systemctl enable --now ssh

echo "==> Tailscale (install per https://tailscale.com/download/linux if missing), then log in with SSH"
# Tailscale SSH = no key management; tailnet identity authenticates the phone.
sudo tailscale up --hostname=max-wsl --ssh

echo "==> tmux plugins (TPM)"
[ -d ~/.tmux/plugins/tpm ] || git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins

IP="$(tailscale ip -4 | head -1)"
echo "==> Done. From the phone (Termux): mosh mint@${IP}"
