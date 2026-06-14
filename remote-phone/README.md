# Remote phone access — drive Claude Code from Android

Work on projects via multiple Claude Code sessions from an Android phone (e.g. while walking),
using a real terminal instead of `/remote-control`. Full design: see
`docs/superpowers/specs/2026-06-14-phone-claude-sessions-design.md`.

## Architecture

```
Termux (Android)  →  Mosh over Tailscale  →  WSL2 Ubuntu (sshd / Tailscale SSH)  →  tmux  →  claude
```

Tailscale runs **inside WSL2**, so WSL is its own tailnet node (`max-wsl`, `100.107.134.26`) — no
Windows↔WSL NAT. Unity / Editor work stays native on the Windows desktop; only code/planning/review
sessions go mobile.

## Daily use

| Action | How |
|--------|-----|
| Connect | Tap the **Termux:Widget** button, or `mosh mint@100.107.134.26` |
| Leave (keep work alive) | **Detach**: `Ctrl+Space` then `d` — never `exit`/Ctrl-D inside tmux |
| Switch / create session | `Ctrl+Space` then `O` (tmux-sessionx) |
| Resume a chat after reboot | `cd <project>` then `claude --continue` |

## Persistence — what survives what

- **Disconnect / sleep / leaving Wi-Fi** → everything (tmux keeps running; mosh+Tailscale reconnect).
- **WSL left idle** → stays up (tailscaled systemd service keeps the VM alive).
- **`exit` inside tmux** → that session dies. Detach instead.
- **Windows reboot** → `windows/wsl-tmux-autostart.vbs` (in Startup) re-boots WSL + a `main` session;
  `@continuum-restore` restores layout; `claude --continue` resumes conversations.

## Files here

- `wsl/setup.sh` — one-time WSL provisioning (mosh, locale, sshd, Tailscale SSH, tmux plugins).
- `termux/connect-claude.sh` — phone connect script; copy to `~/.shortcuts/connect-claude` for the widget.
- `windows/wsl-tmux-autostart.vbs` — copy into the Startup folder to auto-boot WSL+tmux at logon.

## One-time setup recap

**WSL (run `wsl/setup.sh`, or manually):** install `mosh locales openssh-server`, `locale-gen en_US.UTF-8`,
enable `ssh`, `tailscale up --hostname=max-wsl --ssh`, install TPM plugins.

**Windows:** copy `windows/wsl-tmux-autostart.vbs` to
`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\`.

**Phone (Termux from F-Droid — *not* Play Store):**
- `pkg install -y mosh openssh`
- Nerd Font: download JetBrainsMono Nerd Font, place at `~/.termux/font.ttf`, `termux-reload-settings`.
- Extra-keys row: append to `~/.termux/termux.properties`:
  `extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]`
- Install **Termux:Widget**, create `~/.shortcuts/connect-claude` (see `termux/connect-claude.sh`), add widget.

## Troubleshooting (gotchas we hit)

- **`mosh` exits "Did not find mosh server startup message" / locale error** → the UTF-8 locale wasn't
  generated on WSL: `sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8`.
- **`/tmp: Permission denied` in Termux** → Android locks `/tmp`; use `$HOME` (`~`) instead.
- **`pkg: command not found`** → you're in the WSL shell, not a local Termux tab. `pkg` = phone, `apt` = WSL.
  (`whoami` shows `mint` in WSL, `u0_aXXX` on the phone.)
- **Missing glyphs / boxes** → install a Nerd Font as `~/.termux/font.ttf`, then fully restart Termux.
- **SSH "hangs" on connect** → the zsh login shell's tmux auto-attach with no session; ensure a `main`
  session exists (autostart handles this).
