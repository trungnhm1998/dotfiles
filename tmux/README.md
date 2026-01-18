# Tmux Configuration

Terminal multiplexer configuration for macOS and Linux. Provides session management, pane splitting, and seamless integration with Neovim.

## Platform Support

- **macOS**: Primary workflow
- **Linux**: Primary workflow
- **Windows**: Not used (Wezterm workspaces serve the same purpose)

## Files

- `tmux.conf` - Main tmux configuration

## Deployment

Symlinked by deployment scripts:
- **macOS**: `./setup_mac.sh` creates `~/.tmux.conf` → `~/dotfiles/tmux/tmux.conf`
- **Linux**: `./deploy.sh` creates `~/.tmux.conf` → `~/dotfiles/tmux/tmux.conf`

## Key Features

- **Prefix Key**: `Ctrl+Space` (same as Wezterm leader for consistency)
- **Plugin Manager**: TPM (Tmux Plugin Manager)
- **Navigation**: `Ctrl+hjkl` to move between panes (via vim-tmux-navigator)
- **Theme**: Catppuccin Frappe
- **Integration**: Smart pane navigation with Neovim splits

## Key Bindings

| Binding | Action |
|---------|--------|
| `Prefix + v` | Vertical split |
| `Prefix + s` | Horizontal split |
| `Prefix + x` | Close pane |
| `Ctrl+h/j/k/l` | Navigate panes/vim splits |
| `Prefix + I` | Install plugins (TPM) |
| `Prefix + U` | Update plugins (TPM) |

## Post-Installation

1. Install TPM:
   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

2. Launch tmux and press `Prefix + I` to install plugins

3. Restart tmux or run:
   ```bash
   tmux source-file ~/.tmux.conf
   ```

## Plugins

Managed via TPM in `tmux.conf`:
- `tmux-plugins/tpm` - Plugin manager
- `christoomey/vim-tmux-navigator` - Seamless vim/tmux navigation
- `catppuccin/tmux` - Theme

## Integration with Zsh

The zsh configuration (`zsh/zshrc_manager.sh`) automatically attaches to a tmux session when:
- Running on macOS or Linux
- Not inside an IDE terminal (IntelliJ, VSCode, Cursor)
- Tmux is installed

This ensures you always work in a tmux session for session persistence.

## Why Not on Windows?

Windows uses **Wezterm workspaces** instead of tmux because:
- Tmux has poor native Windows support
- Wezterm provides similar session/workspace functionality
- Wezterm pane splitting is more reliable on Windows
- vim-smart-splits handles Neovim integration on Windows
