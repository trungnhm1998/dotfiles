# Zsh Configuration

Shell configuration for macOS and Linux, providing a modern terminal experience with plugins, aliases, and smart integrations.

## Platform Support

- **macOS**: Primary shell
- **Linux**: Primary shell
- **Windows**: Not used (PowerShell is the primary shell on Windows)

## Files

- `zshrc_manager.sh` - Entry point, handles tmux attachment and IDE detection
- `zshrc.sh` - Main configuration (aliases, plugins, environment, prompt)

## Architecture

### Two-File Structure

```
~/.zshrc  →  ~/dotfiles/zsh/zshrc_manager.sh  →  sources zshrc.sh
```

**Why split into two files?**

1. **zshrc_manager.sh** (Entry Point):
   - Detects IDE terminals (IntelliJ, VSCode, Cursor)
   - Auto-attaches to tmux session (only outside IDEs)
   - Sources the main config file

2. **zshrc.sh** (Main Config):
   - Aliases and functions
   - Plugin loading (oh-my-zsh, autosuggestions, syntax highlighting)
   - Environment variables
   - Tool initialization (zoxide, starship, etc.)

### IDE Detection Logic

The manager skips tmux attachment when running in:
- IntelliJ IDEA / JetBrains IDEs (`$TERMINAL_EMULATOR` contains "JetBrains")
- VSCode (`$TERM_PROGRAM` = "vscode")
- Cursor (`$TERM_PROGRAM` = "cursor")

This prevents nested tmux sessions in IDE terminals.

## Deployment

Symlinked by deployment scripts:
- **macOS**: `./setup_mac.sh` creates `~/.zshrc` → `~/dotfiles/zsh/zshrc_manager.sh`
- **Linux**: `./deploy.sh` creates `~/.zshrc` → `~/dotfiles/zsh/zshrc_manager.sh`

## Key Features

### Oh-My-Zsh
- Framework: Installed by `deploy.sh` to `~/.oh-my-zsh`
- Plugins:
  - `zsh-autosuggestions` - Command suggestions from history
  - `zsh-syntax-highlighting` - Syntax highlighting in terminal

### Starship Prompt
- Configuration: `.config/starship.toml`
- Features: Git status, language versions, execution time, custom modules
- Initialization: `eval "$(starship init zsh)"` in `zshrc.sh`

### Modern CLI Tools
- `zoxide` - Smart directory jumping (`cd` aliased to `z`)
- `eza` - Modern ls replacement (`ls`, `ll`, `la`, `lt` aliases)
- `yazi` - File manager with cd-on-exit (`y` alias)
- `bat` - Syntax-highlighted cat
- `ripgrep` - Fast grep replacement

## Key Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `y` | `yazi` | File manager with cd-on-exit wrapper |
| `z` / `cd` | `zoxide` | Smart directory jumping |
| `ls` | `eza` | Colorful file listing |
| `ll` | `eza -l` | Long format |
| `la` | `eza -la` | Show hidden files |
| `lt` | `eza --tree` | Tree view |

## Environment Variables

Set in `zshrc.sh`:
- `XDG_CONFIG_HOME` - Points to `~/.config` (XDG standard)
- `EDITOR` / `VISUAL` - Set to `nvim`
- Language-specific paths (Node, Python, etc.)

## Post-Installation

1. Change default shell (if not already zsh):
   ```bash
   chsh -s $(which zsh)
   ```

2. Restart terminal or source config:
   ```bash
   source ~/.zshrc
   ```

3. Install oh-my-zsh plugins (done by `deploy.sh`):
   ```bash
   git clone https://github.com/zsh-users/zsh-autosuggestions \
     ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
   git clone https://github.com/zsh-users/zsh-syntax-highlighting \
     ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
   ```

## Tmux Integration

On macOS/Linux, `zshrc_manager.sh` automatically:
1. Checks if tmux is installed
2. Detects if running in an IDE terminal
3. Attaches to existing tmux session or creates new one
4. Skips attachment if `TMUX` variable is already set

To disable auto-tmux, comment out the relevant section in `zshrc_manager.sh`.

## Customization

### Adding Aliases
Edit `zshrc.sh` and add in the aliases section:
```bash
alias myalias='command'
```

### Adding Functions
Add to `zshrc.sh`:
```bash
function myfunction() {
    # your code
}
```

### Changing Prompt
Edit `.config/starship.toml` for prompt customization.

### Adding Plugins
1. Install plugin to `~/.oh-my-zsh/custom/plugins/`
2. Add to `plugins=()` array in `zshrc.sh`
3. Restart shell

## Why Not on Windows?

Windows uses **PowerShell 7** (configured in `.config/powershell/`) because:
- PowerShell is the native Windows shell
- Better integration with Windows tooling
- Cross-platform PowerShell supports similar features
- Zsh on Windows (via WSL/Git Bash) has compatibility issues

## Troubleshooting

### Slow Shell Startup
- Check plugin load times with `time zsh -i -c exit`
- Consider lazy-loading plugins
- Profile with `zprof` (add `zmodload zsh/zprof` to start of `zshrc.sh`)

### Plugins Not Loading
- Verify plugin directories exist in `~/.oh-my-zsh/custom/plugins/`
- Check `plugins=()` array in `zshrc.sh`
- Run `omz reload` to reload oh-my-zsh

### Tmux Auto-Attach Not Working
- Verify tmux is installed: `which tmux`
- Check `zshrc_manager.sh` for correct tmux logic
- Ensure not running in IDE terminal

### FZF Unknown Option Errors

**Symptoms:**
- Error: `unknown option: --style` when sourcing ~/.zshrc
- Error: `unknown option: --tmux` when sourcing ~/.zshrc

**Root Cause:**
The `FZF_DEFAULT_OPTS` environment variable in `zshrc.sh` (line 84) contains options that are only available in newer fzf versions:
- `--style full` - Not a valid fzf option (belongs to bat)
- `--tmux center,90%,90%` - Requires fzf >= 0.44.0

**System-Specific Versions:**
- **Debian/Ubuntu**: apt installs fzf 0.42.0 (older, lacks `--tmux`)
- **fzf-git repo**: May have newer features but requires manual install
- **Homebrew**: Typically has latest version

**Solutions:**

1. **Remove incompatible flags** (current approach in repo):
   ```bash
   export FZF_DEFAULT_OPTS="--preview 'fzf-preview.sh {}' --bind 'focus:transform-header:file --brief {}' --layout=reverse"
   ```

2. **Upgrade fzf** (if tmux integration is needed):
   ```bash
   # Remove apt version
   sudo apt remove fzf
   
   # Install latest from git
   git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
   ~/.fzf/install --all
   
   # Or use fzf-tmux wrapper directly
   export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
   export FZF_DEFAULT_OPTS="--preview 'fzf-preview.sh {}' --layout=reverse"
   # Use fzf-tmux for tmux integration instead of --tmux flag
   ```

3. **Check installed fzf version:**
   ```bash
   fzf --version
   ```

**Reference:**
- Issue encountered 2026-01-21: Debian fzf 0.42.0 lacks `--tmux` support
- `--style` is a bat option (line 47 of fzf-preview.sh), not an fzf option
