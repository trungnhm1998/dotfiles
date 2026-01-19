# AGENTS.md

Guidelines for agentic coding tools working in this dotfiles repository.

## Repository Overview

This is a personal dotfiles repository managing terminal-based configurations across macOS, Linux, and Windows. It includes:
- **Editors**: Neovim (LazyVim), IdeaVim
- **Terminals**: Wezterm, Tmux (macOS/Linux), Alacritty
- **Window Managers**: Yabai (macOS), Komorebi (Windows)
- **Shell**: Zsh with custom configurations
- **Utilities**: Yazi (file manager), Lazygit, Starship (prompt), Zoxide (cd replacement)

## Build, Lint & Test Commands

This repository has **no traditional build/test system** - it is a configuration repository. Focus on:

### Deployment/Installation Testing
```bash
# Linux/macOS: Test deployment script
./deploy.sh --help          # Show options
bash -n deploy.sh           # Syntax check (no execution)

# macOS specific
./setup_mac.sh --help

# Windows PowerShell (requires Admin)
.\deploy_windows.ps1 -DryRun  # Preview without executing
.\deploy_windows.ps1 -SkipPackages  # Skip package installation
```

### Code Validation

**Lua (Neovim config):**
```bash
# No explicit linter configured. Rely on:
# - LazyVim's builtin LSP (pyright, tsserver, lua_ls)
# - EditorConfig standards (see .editorconfig)
# - stylua directives in code (see plugins/example.lua)
```

**Shell Scripts:**
```bash
# Syntax check bash/sh scripts
bash -n script.sh
# Use ShellCheck (installed via Mason in Neovim)
shellcheck script.sh
```

**PowerShell:**
```powershell
# Syntax check
Get-Content script.ps1 | Test-ScriptFileInfo
```

### Manual Testing Areas
- After modifying deployment scripts, test the actual symlink creation
- After modifying Neovim config, verify `:Lazy sync` and `:checkhealth` pass
- After modifying shell configs, source them and verify no errors
- Test cross-platform symlink targets match CLAUDE.md architecture

## Code Style Guidelines

### Lua (Neovim & Wezterm Config)

**Formatting & Indentation:**
- Indent: 4 spaces (see `.editorconfig`)
- Max line length: 120 characters
- End files with newline
- Use stylua-compatible formatting

**Imports/Requires:**
```lua
-- Module requires at top of file
local opt = vim.opt
local utils = require("config.utils")

-- Plugin specs use inline requires in opts functions
opts = function(_, opts)
  require("some.module").setup()
  return opts
end
```

**Naming Conventions:**
- Variables: `snake_case` (e.g., `opt`, `opts`, `ensure_installed`)
- Functions: `snake_case` (e.g., `setup_keymaps()`)
- Local vars: Prefix with `local` (Lua idiom)
- Config tables: Use clear names (`opts`, `config`, `settings`)

**Types & Annotations:**
- Use LuaLS annotations for clarity (example: `---@param opts cmp.ConfigSchema`)
- Include type hints in complex functions
- LazyVim plugin specs use OOP-style tables

**Error Handling:**
- Lua configurations are declarative (minimal error handling needed)
- For runtime errors, use `pcall()` in critical paths
- Log issues via print() or vim.notify() in Neovim configs

**File Organization:**
```
.config/nvim/
├── init.lua          # Bootstrap (minimal, just requires config.lazy)
├── lua/config/       # Core config (options, keymaps, autocmds)
└── lua/plugins/      # Plugin specs (one file per plugin group)
```

### Shell Scripts (Bash/Zsh)

**Formatting & Style:**
- Shebang: `#!/bin/bash` or `#!/bin/zsh`
- Indent: 2 spaces (convention for shell)
- Quote all variable expansions: `"$var"` not `$var`
- Use functions for reusable code

**Functions:**
```bash
prompt_install() {
  echo -n "$1 is not installed. Would you like to install it? (y/n) " >&2
  # Logic here
}

check_for_software() {
  echo "Checking to see if $1 is installed"
  if ! [ -x "$(command -v $1)" ]; then
    prompt_install "$1"
  fi
}
```

**Error Handling:**
- Check command availability: `[ -x "$(command -v prog)" ]`
- Test file existence: `[ -f "$file" ]`
- Use `set -e` for fail-fast if script should stop on error

### PowerShell Scripts

**Formatting:**
- Indent: 2 spaces
- Use comment-based help (see `deploy_windows.ps1` header)
- Parameters use `[switch]` or typed parameters: `[string]$var`

**Parameters & Defaults:**
```powershell
param(
    [switch]$SkipPackages,
    [switch]$DryRun,
    [string]$ConfigPath = $PSScriptRoot
)
```

**Error Handling:**
- Use `try/catch` blocks for command failures
- Verify Admin privileges: `#Requires -RunAsAdministrator` or manual check
- Return appropriate exit codes

### Configuration Files (JSON, TOML)

**JSON (e.g., `.luarc.json`, `komorebi.json`):**
- 2 spaces indentation
- Quote keys: `"key": value`
- Include trailing commas for arrays/objects (JSON5 style if supported)

**TOML (e.g., `starship.toml`):**
- Follow TOML spec strictly
- Section headers in `[brackets]`
- Comment complex settings

### EditorConfig Rules

Defined in `.editorconfig` for consistency:
- Lua files: 4 spaces, 120 char max line length, LF line endings
- All files: Insert final newline, LF endings
- Configure IDE/editor to respect `.editorconfig`

## Key File Locations

| Purpose | Path |
|---------|------|
| Neovim Config | `.config/nvim/` |
| Wezterm Config | `.config/wezterm/wezterm.lua` |
| Shell Config | `zsh/zshrc.sh`, `zsh/zshrc_manager.sh` |
| Tmux Config | `tmux/tmux.conf` |
| Komorebi Config | `.config/komorebi/` |
| Yabai Config | `.config/yabai/yabairc` |
| Starship Prompt | `.config/starship.toml` |
| Windows PowerShell | `.config/powershell/Microsoft.PowerShell_profile.ps1` |
| IdeaVim | `.ideavimrc` |

## Important Patterns

**Platform Detection (Lua):**
```lua
if vim.fn.has("win32") == 1 then
  -- Windows-specific code
elseif vim.fn.has("mac") == 1 then
  -- macOS-specific code
else
  -- Linux
end
```

**Symlink Targets:**
- Review CLAUDE.md for exact Windows/macOS/Linux symlink mappings
- Never hardcode absolute paths; use environment variables (`$HOME`, `$XDG_CONFIG_HOME`)

**Deployment Idempotency:**
- Scripts should safely run multiple times
- Backup existing configs before overwriting
- Use `-DryRun` flag when available to preview changes

## Architecture & Design Patterns

**VSCode Keymaps OCP Architecture:**
- See `docs/VSCODE_KEYMAPS_OCP_REFACTORING.md` for detailed documentation on the Open-Closed Principle implementation
- Configuration-driven editor variant detection (Cursor, Antigravity, VSCode)
- Automatic fallback mechanism to VSCode defaults
- When adding new commands or editor variants, follow the patterns documented in the refactoring guide

## No Cursor/Copilot Rules

No `.cursorrules` or `.github/copilot-instructions.md` files exist in this repository. Follow the guidelines in this file and CLAUDE.md.
