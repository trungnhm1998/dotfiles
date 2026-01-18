# Vim Configuration

Legacy vim configurations kept for reference and fallback compatibility.

## Current Status

**Active Editor**: Neovim (configured in `.config/nvim/`)

This directory contains traditional vim configurations that are **not actively used** in the current setup. The primary editor is Neovim with the LazyVim framework.

## Why Keep This Directory?

1. **Fallback**: Provides basic vim functionality on systems without Neovim
2. **Reference**: Historical configurations for migration or plugin research
3. **Compatibility**: Some deployment scripts may reference this directory
4. **Learning**: Examples of traditional vim configuration patterns

## Migration to Neovim

The active Neovim configuration lives in:
- **Location**: `.config/nvim/`
- **Framework**: LazyVim (Lazy.nvim plugin manager)
- **Entry Point**: `.config/nvim/init.lua`
- **Plugins**: Defined in `.config/nvim/lua/plugins/`

Neovim was chosen over traditional vim for:
- Lua configuration (faster, more maintainable than VimScript)
- Better plugin ecosystem (Telescope, LSP, Treesitter)
- Asynchronous plugin loading (faster startup)
- Modern defaults out-of-the-box

## If You Want to Use Traditional Vim

1. Symlink configs:
   ```bash
   ln -sf ~/dotfiles/vim/.vimrc ~/.vimrc
   ln -sf ~/dotfiles/vim ~/.vim
   ```

2. Install vim:
   - **macOS**: `brew install vim`
   - **Linux**: `sudo apt install vim` or equivalent
   - **Windows**: `winget install vim.vim`

3. Install plugin manager (if configured):
   ```bash
   # Vundle, vim-plug, or whatever is in .vimrc
   ```

## Active Vim Configuration: IdeaVim

For JetBrains IDEs, the **`.ideavimrc`** (root level) provides vim keybindings:
- Location: `~/dotfiles/.ideavimrc`
- Platforms: Windows, macOS, Linux
- Features: Vim motions + IDE integrations

This is actively maintained and used alongside Neovim.

## Relationship with .config/nvim/

| Aspect | vim/ (Legacy) | .config/nvim/ (Active) |
|--------|---------------|------------------------|
| Language | VimScript | Lua |
| Framework | Raw/Plugin Manager | LazyVim |
| Maintained | No | Yes |
| Platform | All (fallback) | All (primary) |
| LSP | Limited/CoC | Native (nvim-lspconfig) |

## Recommended Action

If you never use traditional vim:
- Consider removing this directory
- Update deployment scripts to stop symlinking it
- Keep `.ideavimrc` for JetBrains IDEs

If you occasionally use vim on remote servers:
- Keep this directory for basic configuration
- Ensure it has minimal, portable configs
- Avoid heavy plugins that need compilation
