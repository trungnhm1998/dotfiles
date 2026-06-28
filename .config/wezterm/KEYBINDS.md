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
| **PowerShell** | Activates wezterm's leader key table (no timeout — tmux-style) |
| **CMD** | Activates wezterm's leader key table (no timeout — tmux-style) |
| **Cmder** | Activates wezterm's leader key table (no timeout — tmux-style) |

### Status Bar Feedback

When the leader key is active on a non-WSL pane, the status bar on the bottom right shows:

```
[leader] default   19-01-2026 12:34:56
```

Once you press another (bound) key, the `[leader]` indicator disappears. There is **no timeout** — the prefix waits indefinitely, like tmux. Pressing an **unbound** key cancels the prefix and is **swallowed** (not sent to the shell).

The left section colors itself per mode, using the Catppuccin Frappe palette: **leader** = pink (`󱏐`), **resize** = teal (`󰁁`), **copy** = yellow (`󰩫`), **search** = green, **normal** = blue. Each custom `*_mode` key table must define a matching theme section in `wezterm.lua` (`tabline.set_theme`), otherwise tabline errors while rendering that mode and the bar freezes on its previous paint.

### Status bar info (Windows)

- **Right side:** git branch + `●` dirty (focused local repo only) · host badge (local / WSL:distro / ssh host, ssh-aware) · `N ws · N tabs` · focused process. The clock was removed.
- **Tabs:** `index · host-icon · process · repo-or-dir · ◫panes` plus the Claude badge and zoom marker. Host icon: Windows = local, `` = WSL, `` = ssh (the precise Mac/VPS icon shows in the right-side host badge).

---

## Leader Key Bindings (PowerShell/CMD/Cmder)

After pressing `Ctrl+Space`, press any of these keys (no time limit — the prefix waits, like tmux):

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
| `Ctrl+Space` → `h`/`j`/`k`/`l` | Select pane left/down/up/right (tmux `select-pane`) |
| `Ctrl+Space` → `r` | Enter **sticky resize mode**: `h`/`j`/`k`/`l` or arrows resize repeatedly; `Esc`/`q` exits (tmux `bind -r resize-pane`). The tab bar shows a teal `󰁁` indicator while active. **No-op in a single-pane tab** — there is nothing to resize, so the prefix just exits (matches tmux). |

### Workspace Management

Workspaces are WezTerm's equivalent of tmux sessions. These bindings deliberately mirror tmux's session keys.

| Keybind | Action | tmux equivalent |
|---------|--------|-----------------|
| `Ctrl+Space` → `w` | Create / switch to a **named** workspace (prompt) | — |
| `Ctrl+Space` → `$` (Shift+4) | **Rename** the active workspace | `prefix $` |
| `Ctrl+Space` → `)` (Shift+0) | Next workspace (alphabetical) | `prefix )` |
| `Ctrl+Space` → `(` (Shift+9) | Previous workspace | `prefix (` |
| `Ctrl+Space` → `Shift+L` | Toggle to the **last-used** workspace | `prefix L` |
| `Ctrl+Space` → `f` | **Fuzzy switcher** — existing workspaces + `zoxide` dirs | — |
| `Ctrl+Space` → `g` | **Remote picker** — fuzzy list of WSL distros + `~/.ssh/config` hosts + extras; lands in a workspace named for the host (remote tmux owns `Ctrl+Space` there) | — |
| `Ctrl+Space` → `Shift+S` | Workspace list launcher (**type to filter**) | `prefix s` |

> `f` uses the [`smart_workspace_switcher`](https://github.com/MLFlexer/smart_workspace_switcher.wezterm) plugin (needs `zoxide` on PATH). Picking a zoxide directory spawns/switches to a workspace rooted there — like `tmux-sessionizer`. `Shift+L` remembers your previous workspace via `wezterm.GLOBAL` and is guarded so a renamed/closed workspace won't spawn an empty phantom.

### Session & Tools

| Keybind | Action | tmux equivalent |
|---------|--------|-----------------|
| `Ctrl+Space` → `z` | Toggle pane **zoom** (fullscreen the active pane) | `prefix z` |
| `Ctrl+Space` → `:` (Shift+;) | **Debug overlay / Lua REPL** | `prefix :` |

### Launcher

| Keybind | Action |
|---------|--------|
| `Ctrl+Space` → `Shift+T` | Show launcher (create new tab from templates) |

### Copy Mode, Paste & Send-Prefix

| Keybind | Action | tmux equivalent |
|---------|--------|-----------------|
| `Ctrl+Space` → `Escape` | Enter **copy mode** (vi-style; also `Ctrl+Shift+X`) | `bind Escape copy-mode` |
| `Ctrl+Space` → `]` | Paste from clipboard | `bind ] paste-buffer` |
| `Ctrl+Space` → `Space` | Send a literal `Ctrl+Space` (NUL) to the program | `send-prefix` |

In copy mode: `h`/`j`/`k`/`l` move · `v` start selection · `V` line · `Ctrl+v` block · `y` or `Enter` copy-and-exit · `/` search · `g`/`G` top/bottom · `Ctrl+u`/`Ctrl+d` half-page · `q`/`Esc` exit — matching `mode-keys vi` + tmux-yank.

### Cancelling the prefix

There is **no explicit cancel key** (tmux-style). To dismiss the prefix without acting, press any unbound key — it is swallowed. As a hard reset, `Ctrl+Shift+Space` clears the key-table stack from anywhere (lockout backstop).

> **Known limitation — modified keys in the leader table.** On Windows WezTerm, a leader-table entry that needs a **modifier** (`Ctrl`/`Shift`) does **not** reliably fire — only plain keys do (see [wezterm #6824](https://github.com/wezterm/wezterm/issues/6824)). This is why resize is `r` (not `Shift+R`) and send-prefix is `Space` (not `Ctrl+Space Ctrl+Space`). Some shifted binds listed above (e.g. `$`, `Shift+L`, `Shift+T`) may be affected; the plain-key binds are the reliable ones.

---

## Non-Leader Global Keybindings

These keybindings work from anywhere and don't require the leader key:

| Keybind | Action |
|---------|--------|
| `Alt+Enter` | *Disabled* (default wezterm behavior) |
| `Ctrl+Alt+U` | *Disabled* (user-defined override) |
| `Ctrl+Alt+D` | *Disabled* (user-defined override) |
| `Ctrl+Shift+Space` | Clear the key-table stack (leader/resize/copy lockout backstop) |

> **Moved:** the debug overlay used to be on `Ctrl+Shift+L` (written `key = "L", mods = "CTRL"`, which WezTerm reads as Ctrl+**Shift**+L). It now lives in leader mode at `Ctrl+Space` → `:`. `Ctrl+L` is therefore free for the shell's clear-screen and for smart-splits "navigate right".

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

**Leader = `Ctrl+Space`** — active on non-WSL panes; WSL panes pass `Ctrl+Space` straight through to tmux.

| Group | Keys (after `Ctrl+Space`) |
|-------|---------------------------|
| **Tabs** | `t` new · `n`/`p` next/prev · `1`–`9` goto · `,` rename · `&` close |
| **Panes** | `v` split-H · `s` split-V · `x` close · `z` zoom · `h/j/k/l` select · `r` resize mode |
| **Copy/paste** | `Escape` copy mode (vi) · `]` paste · `Space` send-prefix |
| **Workspaces** | `w` new/named · `$` rename · `(`/`)` prev/next · `Shift+L` last · `f` fuzzy · `Shift+S` list |
| **Tools** | `:` debug REPL · `Shift+T` launcher |
| **Pane nav** (no leader) | `Ctrl+H/J/K/L` move · `Meta+H/J/K/L` resize · `Ctrl+Shift+Space` reset |

---

## Usage Examples

### Example 1: Create and Split a Pane

1. Open Wezterm in a PowerShell tab
2. Press `Ctrl+Space` + `t` → Creates a new tab
3. Press `Ctrl+Space` + `v` → Splits the pane horizontally
4. Navigate between panes with `Ctrl+H` or `Ctrl+L`

### Example 2: Work with Workspaces (like tmux sessions)

1. Press `Ctrl+Space` + `w`, type a name (e.g. "project-a"), press Enter
2. Create another the same way (e.g. "notes")
3. Flip between the two with `Ctrl+Space` + `Shift+L` (last-used) — the fastest switch
4. Or cycle with `Ctrl+Space` + `(` / `)`, or fuzzy-jump (incl. zoxide dirs) with `Ctrl+Space` + `f`
5. Rename the current workspace with `Ctrl+Space` + `$`

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
- `key_tables.leader_mode` - Stores all leader key bindings

### Customization Tips

To modify keybindings:

1. Edit `~/.config/wezterm/wezterm.lua`
2. For non-leader keys: Add to `config.keys` table
3. For leader keys: Add to `config.key_tables.leader_mode` table
4. Reload with: `wezterm` command or reload configuration in settings

---

## Prefix Behavior (no timeout)

- **Leader timeout**: none — the prefix waits indefinitely for the next key, like tmux's prefix.
- Pressing any **unmapped** key exits the prefix and is **swallowed** (not sent to the pane).
- `Escape` now enters **copy mode** (it no longer cancels). To dismiss the prefix, press any unbound key; `Ctrl+Shift+Space` is the hard-reset backstop.

---

## Terminal Multiplexing

### Wezterm Native

- **Tabs** - Use `Ctrl+Space` + number keys or `t`/`p`/`n`
- **Panes** - Use `Ctrl+Space` + `v`/`s` or smart-splits navigation
- **Workspaces** - `Ctrl+Space` + `w` (new), `(`/`)` (cycle), `Shift+L` (last), `f`/`Shift+S` (pick), `$` (rename)

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
- There is no leader timeout; the prefix waits until you press a key
- To view wezterm version and config: Press `Ctrl+Space` → `:` for the debug overlay / Lua REPL
- Configuration applies on wezterm restart or config reload

---

## See Also

- [Wezterm Official Documentation](https://wezfurlong.org/wezterm/)
- [vim-smart-splits.nvim Plugin](https://github.com/mrjones2014/smart-splits.nvim)
- [Tmux Documentation](https://man.openbsd.org/tmux)
