# Wezterm Keybindings Manual

## Overview

This document describes all keybindings configured in the Wezterm terminal emulator for this dotfiles setup. The configuration uses a **dynamic leader key** (`Ctrl+Space`) that behaves differently based on the active pane's domain (WSL or local).

---

## Leader Key (`Ctrl+Space`)

The leader key is a modal system that lets you perform multiple actions after a single key combination.

### Behavior by Active Pane

| Active Pane | `Ctrl+Space` Behavior |
|-------------|----------------------|
| **WSL (Linux)** | Passes `Ctrl+Space` through to tmux running inside WSL |
| **PowerShell** | Activates wezterm's leader key table (1 second timeout) |
| **CMD** | Activates wezterm's leader key table (1 second timeout) |
| **Cmder** | Activates wezterm's leader key table (1 second timeout) |

### Status Bar Feedback

When the leader key is active on a non-WSL pane, the status bar on the bottom right shows:

```
[leader] default   19-01-2026 12:34:56
```

Once you press another key or the timeout expires (1 second), the `[leader]` indicator disappears.

---

## Leader Key Bindings (PowerShell/CMD/Cmder)

After pressing `Ctrl+Space`, you can press any of these keys within 1 second:

### Tab Management

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `t` | Create new tab |
| `Ctrl+Space` → `p` | Go to previous tab |
| `Ctrl+Space` → `n` | Go to next tab |
| `Ctrl+Space` → `1` through `9` | Switch to tab number 1-9 |
| `Ctrl+Space` → `,` | Rename current tab |
| `Ctrl+Space` → `&` (Shift+7) | Close current tab (with confirmation) |

### Pane Management

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `v` | Split pane horizontally |
| `Ctrl+Space` → `Shift+\|` | Split pane horizontally (alternative) |
| `Ctrl+Space` → `s` | Split pane vertically |
| `Ctrl+Space` → `Shift+-` | Split pane vertically (alternative) |
| `Ctrl+Space` → `x` | Close current pane (with confirmation) |

### Workspace Management

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `Shift+W` | Create new workspace or switch to existing one |
| `Ctrl+Space` → `Shift+S` | Show workspace list (launcher) |

### Launcher

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `Shift+T` | Show launcher (create new tab from templates) |

### Cancel Leader Mode

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `Escape` | Cancel leader mode without executing any action |

---

## Non-Leader Global Keybindings

These keybindings work from anywhere and don't require the leader key:

| Keybind | Action |
|---------|--------|
| `Ctrl+L` | Show debug overlay (Wezterm debug info) |
| `Alt+Enter` | *Disabled* (default wezterm behavior) |
| `Ctrl+Alt+U` | *Disabled* (user-defined override) |
| `Ctrl+Alt+D` | *Disabled* (user-defined override) |

---

## Pane Navigation with Vim Smart Splits

The `vim-smart-splits.nvim` plugin is integrated. These bindings allow seamless navigation between panes:

| Keybind | Action |
|---------|--------|
| `Ctrl+H` | Navigate to left pane |
| `Ctrl+J` | Navigate to down pane |
| `Ctrl+K` | Navigate to up pane |
| `Ctrl+L` | Navigate to right pane |
| `Meta+H` | Resize pane left |
| `Meta+J` | Resize pane down |
| `Meta+K` | Resize pane up |
| `Meta+L` | Resize pane right |

---

## Keyboard Shortcuts Summary

### Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                   LEADER KEY: Ctrl+Space                    │
├─────────────────────────────────────────────────────────────┤
│ TAB MANAGEMENT                                              │
│  t = New Tab        | p = Prev Tab   | n = Next Tab         │
│  1-9 = Goto Tab     | , = Rename     | & = Close Tab        │
├─────────────────────────────────────────────────────────────┤
│ PANE MANAGEMENT                                             │
│  v / | = Split H    | s / - = Split V | x = Close Pane     │
├─────────────────────────────────────────────────────────────┤
│ WORKSPACE                                                   │
│  Shift+W = New       | Shift+S = List                       │
├─────────────────────────────────────────────────────────────┤
│ Shift+T = Launcher  | Escape = Cancel                       │
├─────────────────────────────────────────────────────────────┤
│ PANE NAVIGATION (No Leader Needed)                          │
│  Ctrl+H/J/K/L = Move   | Meta+H/J/K/L = Resize            │
│                                                             │
│ NON-WSL PANES: Ctrl+Space activates leader                │
│ WSL PANES: Ctrl+Space passes to tmux                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Example 1: Create and Split a Pane

1. Open Wezterm in a PowerShell tab
2. Press `Ctrl+Space` + `t` → Creates a new tab
3. Press `Ctrl+Space` + `v` → Splits the pane horizontally
4. Navigate between panes with `Ctrl+H` or `Ctrl+L`

### Example 2: Work with Workspaces

1. Press `Ctrl+Space` + `Shift+W`
2. Type a workspace name (e.g., "project-a")
3. Press Enter
4. Switch back with `Ctrl+Space` + `Shift+S`

### Example 3: Switch to WSL Tab and Use Tmux

1. Click on the WSL tab
2. Press `Ctrl+Space` → This sends `Ctrl+Space` to tmux (not wezterm)
3. Tmux leader key is now active (e.g., tmux prefix)
4. Use tmux keybindings normally

### Example 4: Rename a Tab

1. Press `Ctrl+Space` + `,`
2. A prompt appears asking for the new tab name
3. Type your new name (e.g., "Editing")
4. Press Enter

---

## Configuration File Reference

The main configuration is located at: `~/.config/wezterm/wezterm.lua`

### Key Functions

- `is_wsl_pane(pane)` - Detects if the active pane is running in WSL
- `action_callback` - Dynamic key behavior based on pane domain
- `ActivateKeyTable` - Simulates leader key for non-WSL panes
- `key_tables.leader` - Stores all leader key bindings

### Customization Tips

To modify keybindings:

1. Edit `~/.config/wezterm/wezterm.lua`
2. For non-leader keys: Add to `config.keys` table
3. For leader keys: Add to `config.key_tables.leader` table
4. Reload with: `wezterm` command or reload configuration in settings

---

## Timeout Behavior

- **Leader Key Timeout**: 1000 milliseconds (1 second)
- After pressing `Ctrl+Space`, you have 1 second to press the next key
- Pressing any unmapped key exits leader mode
- Pressing `Escape` explicitly cancels leader mode

---

## Terminal Multiplexing

### Wezterm Native

- **Tabs** - Use `Ctrl+Space` + number keys or `t`/`p`/`n`
- **Panes** - Use `Ctrl+Space` + `v`/`s` or smart-splits navigation
- **Workspaces** - Use `Ctrl+Space` + `Shift+W`/`S`

### Tmux in WSL

- When focused on a WSL pane, use tmux keybindings directly
- `Ctrl+Space` in WSL activates tmux (not wezterm)
- Allows full tmux session management inside Linux

---

## Troubleshooting

### Leader Mode Not Activating

- Ensure you're on a **non-WSL pane** (PowerShell, CMD, or Cmder)
- Check that `Ctrl+Space` is not bound elsewhere on your system
- Verify the status bar shows `[leader]` when pressing `Ctrl+Space`

### Ctrl+Space Not Reaching Tmux

- Ensure you're on a **WSL pane** (check tab or split focus)
- Use `Ctrl+Space` + `s` (Shift+S) to see active workspace/pane
- Confirm tmux is running in the WSL environment

### Pane Navigation Not Working

- `Ctrl+H/J/K/L` requires the `vim-smart-splits.nvim` plugin
- Verify plugin is loaded in wezterm
- Check for conflicting keybinds in your shell configuration

---

## Notes

- All keybindings are case-sensitive (e.g., `Shift+S` is different from `s`)
- The leader timeout resets each time you press a valid key
- To view wezterm version and config: Press `Ctrl+L` for debug overlay
- Configuration applies on wezterm restart or config reload

---

## See Also

- [Wezterm Official Documentation](https://wezfurlong.org/wezterm/)
- [vim-smart-splits.nvim Plugin](https://github.com/mrjones2014/smart-splits.nvim)
- [Tmux Documentation](https://man.openbsd.org/tmux)
