# WezTerm: preserve working directory on pane split and new tab

- **Date:** 2026-06-25
- **Status:** Approved (design)
- **Scope:** `.config/wezterm/wezterm.lua` — Windows / native-pwsh-pane path only

## Problem

Splitting a pane via the WezTerm leader bindings (`Leader v`, `Leader s`, and the
`|` / `-` aliases) opens the new pane in the user's home directory instead of the
active pane's current working directory. Expected behavior (tmux-like): a new
split — and a new tab — starts in the same directory as the pane it spawned from.

## Root cause

`split_current_pane()` (`wezterm.lua:292-307`) builds a `SpawnCommand` and assigns
the working directory like this:

```lua
local cwd = pane:get_current_working_dir()
if cwd then
    command.cwd = cwd
end
```

Two facts make this silently wrong on the installed build (`wezterm 20260607`):

1. `pane:get_current_working_dir()` returns a **`Url` object**, not a string, since
   WezTerm `20240127-113634-bbcac864`.
   (<https://wezterm.org/config/lua/pane/get_current_working_dir.html>)
2. `SpawnCommand.cwd` expects a **string path**; when it cannot use the supplied
   value it "fall[s] back to using the home directory of the current user."
   (<https://wezterm.org/config/lua/SpawnCommand.html>)

Passing the `Url` userdata into a string field therefore produces the observed
home-directory fallback.

The shell side is healthy and **not** implicated: `Invoke-Starship-PreCommand`
(`Microsoft.PowerShell_profile.ps1:53-61`) emits OSC 7 correctly, and
`wezterm cli list` confirmed WezTerm holds the accurate per-pane directory across
multiple panes and drives (verified 2026-06-25 — e.g. one pane `…/dotfiles`,
another on drive `H:`).

The `Url` object exposes a `file_path` property that "decodes the path field and
interprets it as a file path" — the native string `SpawnCommand.cwd` wants.
(<https://wezterm.org/config/lua/wezterm.url/Url.html>)

## Design

Introduce one shared helper and route both spawn sites through it.

### `pane_command(pane)` helper

Defined inside the `if is_windows` block, immediately above `split_current_pane`
(so both it and the `leader_mode` key table can call it). `pwsh` is already
module-scoped and in scope.

```lua
-- Build a SpawnCommand for actions launched from the current pane: stay in the
-- same domain, relaunch pwsh for local panes, and inherit the active pane's
-- working directory. get_current_working_dir() returns a Url object
-- (WezTerm 20240127+); SpawnCommand.cwd wants a string, so use .file_path.
local function pane_command(pane)
    local command = { domain = "CurrentPaneDomain" }
    if pane:get_domain_name() == "local" then
        command.args = { pwsh, "-NoLogo" }
    end
    local cwd = pane:get_current_working_dir()
    if cwd then
        command.cwd = cwd.file_path
    end
    return command
end
```

### Call sites

`split_current_pane(direction)` becomes:

```lua
local function split_current_pane(direction)
    return wezterm.action_callback(function(window, pane)
        window:perform_action(
            act.SplitPane({ direction = direction, command = pane_command(pane) }),
            pane
        )
    end)
end
```

The `Leader t` (new tab) handler becomes:

```lua
{
    key = "t",
    action = wezterm.action_callback(function(window, pane)
        window:perform_action(act.SpawnCommandInNewTab(pane_command(pane)), pane)
    end),
},
```

`Leader t` previously set no `cwd` at all and so already inherited the directory
via WezTerm's domain-match default; routing it through the helper makes that
behavior explicit and uniform rather than implicit, and removes the duplicated
`domain` + pwsh-args block.

## Why it is safe

- **Type-robust:** if `get_current_working_dir()` ever returned a string instead of
  a `Url` (it does not on this build), `("…").file_path` evaluates to `nil` in Lua
  without error — `command.cwd` stays unset and WezTerm falls back to its inherit
  behavior. No crash either way.
- **Non-file URLs:** an `ftp://`-style cwd would yield a `nil` `file_path`;
  `command.cwd` stays unset and WezTerm falls back. Acceptable — local pwsh panes
  always report `file://` URLs.
- **WSL / Zellij panes unaffected:** those panes pass `Ctrl+Space` straight through
  (`wezterm.lua:275-277`), so `leader_mode` — and therefore `pane_command` — never
  executes in them. This change touches only the native-pwsh-pane path.

## Files changed

| File | Change |
|------|--------|
| `.config/wezterm/wezterm.lua` | Add `pane_command` helper; simplify `split_current_pane` and the `Leader t` handler to call it. Net ≈ −8 lines. |

## Verification

1. Reload the WezTerm config.
2. `cd` into a non-home directory (e.g. the dotfiles repo).
3. `Leader v`, `Leader s`, `|`, `-` — each new split starts in that directory.
4. `Leader t` — the new tab starts in that directory.
5. Optional cross-check: `wezterm cli list --format json`.

## Out of scope

- macOS/Linux behavior — the leader bindings and helper live in the `if is_windows`
  block; nothing there changes.
- The `smart-splits` plugin — it handles `Ctrl+hjkl` navigation/resize, not pane
  creation.
- OSC 7 emission in the PowerShell profile — confirmed working.

## Risks

Minimal. A single-file Lua config change with graceful degradation. The only
observable behavior change is the intended one: new splits and tabs inherit the
active pane's working directory.
