# WezTerm: preserve working directory on pane split and new tab

- **Date:** 2026-06-25
- **Status:** Implemented & verified. **Note:** the originally-approved fix
  (`command.cwd = cwd.file_path`) was wrong on Windows — see "Root cause" and
  "Correction" below. The shipped fix is *not* to set `cwd` at all.
- **Scope:** `.config/wezterm/wezterm.lua` — Windows / native-pwsh-pane path only

## Problem

Splitting a pane via the WezTerm leader bindings (`Leader v`, `Leader s`, and the
`|` / `-` aliases) opens the new pane in the user's home directory instead of the
active pane's current working directory. Expected behavior (tmux-like): a new
split — and a new tab — starts in the same directory as the pane it spawned from.

## Root cause

`split_current_pane()` built a `SpawnCommand` and assigned the working directory
from the pane's reported cwd:

```lua
local cwd = pane:get_current_working_dir()
if cwd then
    command.cwd = cwd          -- original code
end
```

The shell side is healthy and **not** implicated: `Invoke-Starship-PreCommand`
(`Microsoft.PowerShell_profile.ps1:53-61`) emits OSC 7 correctly, and
`wezterm cli list` confirmed WezTerm holds the accurate per-pane directory across
multiple panes and drives (verified 2026-06-25 — e.g. one pane `…/dotfiles`,
another on drive `H:`).

The break is entirely in how `cwd` is fed back to `SpawnCommand`:

1. `pane:get_current_working_dir()` returns a **`Url` object**, not a string, since
   WezTerm `20240127-113634-bbcac864` (installed build: `20260607`).
   (<https://wezterm.org/config/lua/pane/get_current_working_dir.html>)
2. `SpawnCommand.cwd` expects a **string path**; when it cannot use the supplied
   value it "fall[s] back to using the home directory of the current user."
   (<https://wezterm.org/config/lua/SpawnCommand.html>)

So the original `command.cwd = <Url object>` was unusable → home-dir fallback.

**The non-obvious part — and why `.file_path` is *also* wrong on Windows:** the
`Url` object's `file_path` property returns the decoded *path component* of the
URL, which on Windows is a Unix-style string with a leading slash. For a cwd of
`file:///C:/Users/mint/dotfiles`, `cwd.file_path` is **`/C:/Users/mint/dotfiles`**.
Windows rejects that as a directory, which WezTerm logged verbatim:

```
WARN  mux::domain > Directory "/C:/Users/mint/dotfiles" is not readable and will
not be used for the command we are spawning: The filename, directory name, or
volume label syntax is incorrect. (os error 123)
```

`os error 123` is `ERROR_INVALID_NAME`. The result is the same home-dir fallback.
(The WezTerm docs' own `file_path` example, `file://host/some/path` →
`/some/path`, shows this Unix-style shape but doesn't call out the Windows
drive-letter consequence.)
(<https://wezterm.org/config/lua/wezterm.url/Url.html>)

**Conclusion:** any attempt to compute `cwd` ourselves from
`get_current_working_dir()` and feed it to `SpawnCommand.cwd` is fighting the API.
The correct value is the one WezTerm already derives internally.

## Design

**Do not set `cwd`.** A `SpawnCommand` whose `domain` is `"CurrentPaneDomain"`
already inherits the active pane's working directory, and WezTerm converts the
pane's cwd URL to a native OS path *correctly* on its own:

> "If omitted, wezterm will infer a value based on the active pane… If the active
> pane matches the domain specified in this `SpawnCommand` instance then the
> current working directory of the active pane will be used."
> (<https://wezterm.org/config/lua/SpawnCommand.html>)

Introduce one shared helper and route both spawn sites through it. The helper
sets the domain and (for local panes) the program, and deliberately leaves `cwd`
unset.

### `pane_command(pane)` helper

Defined inside the `if is_windows` block, immediately above `split_current_pane`
(so both it and the `leader_mode` key table can call it). `pwsh` is already
module-scoped and in scope.

```lua
-- Build a SpawnCommand for actions launched from the current pane: keep the
-- same domain and relaunch pwsh for local panes. Deliberately do NOT set `cwd`:
-- a CurrentPaneDomain command already inherits the active pane's working
-- directory, and WezTerm converts that URL to a native path correctly. Setting
-- cwd ourselves from get_current_working_dir().file_path breaks on Windows --
-- it returns a "/C:/..." path WezTerm rejects (os error 123), silently falling
-- back to the home directory.
local function pane_command(pane)
    local command = { domain = "CurrentPaneDomain" }
    if pane:get_domain_name() == "local" then
        command.args = { pwsh, "-NoLogo" }
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

`Leader t` already set no `cwd` and so already inherited correctly; routing it
through the helper removes the duplicated `domain` + pwsh-args block and keeps
both spawn sites consistent.

## Why it is safe

- **Uses WezTerm's own mechanism:** cwd inheritance for a `CurrentPaneDomain`
  spawn is the documented, supported behavior — no manual path conversion to get
  wrong across platforms.
- **WSL / Zellij panes unaffected:** those panes pass `Ctrl+Space` straight through
  (`wezterm.lua:275-277`), so `leader_mode` — and therefore `pane_command` — never
  executes in them. This change touches only the native-pwsh-pane path.

## Correction (history)

The first implementation used `command.cwd = cwd.file_path` (committed as
`fix(wezterm): preserve cwd on pane split via Url.file_path`). It did **not** work
— `file_path` yields `/C:/…` on Windows (see Root cause). The shipped fix removes
the explicit `cwd` entirely. If reading git history, treat the `.file_path` commit
as superseded.

## Verification (as performed)

1. **Mechanism proof (CLI):** `wezterm cli split-pane --pane-id <pwsh pane>` with
   **no** `--cwd` produced a new pane in the source pane's directory
   (`H:/project/AI/better-ccflare`), both with and without an explicit
   `-- pwsh -NoLogo`. Confirms inheritance does the right thing on this machine.
2. **Config-path proof (log marker):** a temporary `wezterm.log_warn` inside
   `pane_command` confirmed the fixed (no-`cwd`) code actually ran on a real
   `Ctrl+Space v` split after `Ctrl+Shift+R`, and **no** `os error 123` appeared
   at or after that point. (Marker removed; never committed.)
3. **Live state:** `wezterm cli list` showed all panes/tabs reporting their correct
   directories.

Standing regression check: `wezterm show-keys` must print `Key Table: leader_mode`
and exit `0` (proves the config parses; a Lua error falls back to defaults).

## Out of scope

- macOS/Linux behavior — the leader bindings and helper live in the `if is_windows`
  block; nothing there changes.
- The `smart-splits` plugin — it handles `Ctrl+hjkl` navigation/resize, not pane
  creation.
- OSC 7 emission in the PowerShell profile — confirmed working.

## Risks

Minimal. A single-file Lua config change that removes code and defers to WezTerm's
built-in inheritance. The only observable behavior change is the intended one: new
splits and tabs inherit the active pane's working directory.
