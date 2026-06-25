# WezTerm tmux-faithful prefix emulation — design

- **Date:** 2026-06-25
- **Branch:** `feat/zellij-windows`
- **Status:** Approved design (pre-implementation)
- **Scope:** `.config/wezterm/wezterm.lua` (native pwsh panes only) + `.config/wezterm/KEYBINDS.md`

## Problem

WezTerm's Windows leader (`Ctrl+Space`) is already a modal key-table emulation of a
tmux prefix (`wezterm.lua:271-291`, `key_tables.leader_mode` at `:335-437`), but it
diverges from tmux in ways that break muscle memory:

1. It **times out after 1 second** (`timeout_milliseconds = 1000`, `:285`). tmux's prefix
   never times out — it waits indefinitely for the next key.
2. **No send-prefix** — `Ctrl+Space Ctrl+Space` can't send a literal `Ctrl+Space` to the
   running program (tmux `bind C-Space send-prefix`).
3. **Unbound keys fall through to the shell** — tmux cancels the prefix and swallows the key.
4. **No repeatable mode** — tmux `bind -r` lets you repeat resize without re-pressing prefix.
5. **No prefix-driven copy/scroll mode** wired to the user's tmux copy-mode-vi muscle memory.

The user's daily multiplexer muscle memory comes from their tmux config
(`tmux/tmux-keybindings.conf` + `tmux/reset.conf`), so "behave like tmux" means **mirror
that specific config**, not generic defaults.

## Goals

- Prefix-pending state waits **indefinitely** (no timeout).
- `Ctrl+Space Ctrl+Space` sends a literal `Ctrl+Space` (NUL) to the pane (send-prefix).
- Keys not bound in the prefix table are **swallowed** (not sent to the shell), as in tmux.
- A **repeatable** (sticky) resize mode.
- A prefix-driven **copy / scroll mode** matching the user's tmux copy-mode-vi.
- The prefix key map **mirrors the user's effective tmux binds** where a parallel exists.

## Non-goals

- No change to WSL panes (pass `Ctrl+Space` to real tmux) or Zellij panes (stock, pass
  through). The conditional routing in `wezterm.lua:271-291` is preserved verbatim; **all
  changes are confined to the native-pwsh `else` branch and the key tables it activates.**
- No change to the global smart-splits navigation/resize (`Ctrl+hjkl` / `Meta+hjkl`,
  `wezterm.lua:540-554`) — the new leader binds coexist with it.
- No port of this to macOS/Linux (those use real tmux).

## Verified WezTerm mechanics

Confirmed against the official docs (`wezterm.org/config/key-tables.html`,
`.../keyassignment/ActivateKeyTable.html`, `wezterm.org/copymode.html`):

| Field on `ActivateKeyTable` | Default | Behavior |
|---|---|---|
| `timeout_milliseconds` | none (no expiry) | Omit ⇒ **never times out**. Timer resets on each matching key. |
| `one_shot` | `true` | Pops the table after one key press. |
| `prevent_fallback` | `false` | When `true`, an unmatched key **halts further stack matching** — the key is *not* passed to the pane (i.e. swallowed). Docs warn this can "lock yourself out" with no `PopKeyTable` — that risk applies to `one_shot=false` tables. |
| `until_unknown` | `false` | When `true`, an unmatched key pops the table **then keeps matching down the stack** (key still reaches the pane). Not what we want for "swallow". |
| `replace_current` | `false` | Acts as an implicit `PopKeyTable` before pushing — explicit when entering a sub-table. |

Unmatched-key behavior: default = falls through to the pane; `until_unknown` = pop then
fall through; **`prevent_fallback` = swallowed**. So **swallow ⇒ `prevent_fallback = true`**.

Copy mode: `ActivateCopyMode` enters the built-in `copy_mode` key table (vi-style by
default: `hjkl`, `v`/`V`/`Ctrl+v` selection, `y` → `CopyTo ClipboardAndPrimarySelection`
then close, `/` search + `search_mode`, `g`/`G`, `Ctrl+u`/`Ctrl+d` half-page,
`Ctrl+b`/`Ctrl+f` page, `q`/`Esc`/`Ctrl+c`/`Ctrl+g` exit). Extend (don't replace) via
`wezterm.gui.default_key_tables().copy_mode`. `ClearKeyTableStack` empties the whole stack.

## The user's effective tmux config (mirror target)

`reset.conf` runs `unbind-key -a` then rebinds the full tmux default set;
`tmux-keybindings.conf` then overrides a subset. Effective custom layer:

| tmux bind | Meaning |
|---|---|
| `set -g prefix C-Space` / `bind C-Space send-prefix` | prefix = Ctrl+Space; double-tap sends literal |
| `bind s split-window -c "#{pane_current_path}"` | `s` → split top/bottom, keep cwd |
| `bind v split-window -h -c "#{pane_current_path}"` | `v` → split left/right, keep cwd |
| `bind t new-window -c "#{pane_current_path}"` | `t` → new window |
| `bind r source-file ~/.tmux.conf` | `r` → reload config |
| `setw -g mode-keys vi` | vi copy mode |
| `bind h/j/k/l select-pane -L/-D/-U/-R` | `hjkl` → select pane |
| `unbind [` + `bind Escape copy-mode` | copy mode entered via **`Escape`** (`[` unbound) |
| `bind-key -T copy-mode-vi v send -X begin-selection` | `v` = begin selection |
| (default, still active) `bind ] paste-buffer` | `]` → paste |
| (default, still active) `bind -r C-Up/Down/Left/Right resize-pane` | repeatable resize on Ctrl+arrows |
| (default, still active) `bind -r M-Up/... resize-pane -U 5` | repeatable resize on Alt+arrows (step 5) |
| (default) `n`/`p`, `0-9`, `x`, `z`, `&`, `$`, `,` | next/prev window, select window, kill-pane, zoom, kill-window, rename-session, rename-window |
| tmux-yank plugin | `y` in copy-mode-vi = copy selection to system clipboard |

Splits already match the current WezTerm `s`/`v`. The notable divergences to fix:
copy mode on `Escape` (not `[`), send-prefix, `r`=reload, `hjkl`=pane select, `]`=paste,
repeatable resize.

## Design

### 1. Prefix-pending activation (native pwsh branch)

`wezterm.lua:280-288`, the `else` branch, changes from:

```lua
act.ActivateKeyTable({ name = "leader_mode", one_shot = true, timeout_milliseconds = 1000 })
```
to:
```lua
act.ActivateKeyTable({ name = "leader_mode", one_shot = true, prevent_fallback = true })
```

- No `timeout_milliseconds` ⇒ waits indefinitely.
- `prevent_fallback = true` ⇒ unbound keys swallowed (tmux cancel-and-discard).
- `one_shot = true` ⇒ exactly one command key, then exit — and because the table auto-pops
  after a single key, the `prevent_fallback` lock-out risk does not apply to the prefix.

The WSL/Zellij `if` branch (`:275-279`) is unchanged.

### 2. `leader_mode` key map (mirror tmux)

Add/modify entries in `key_tables.leader_mode` (`:336-428`):

| Key | Action | Note |
|---|---|---|
| `Ctrl+Space` | `SendKey{ key=" ", mods="CTRL" }` | **new** — send-prefix (emits NUL). Beats the global `Ctrl+Space` callback because the active table is searched first. |
| `Escape` | `ActivateCopyMode` | **changed** — was `PopKeyTable`. tmux `bind Escape copy-mode`. |
| `r` | `ReloadConfiguration` | **new** — tmux `bind r source-file`. |
| `R` (`SHIFT`) | `ActivateKeyTable{ name="resize_mode", one_shot=false, replace_current=true }` | **new** — enter sticky resize. |
| `h`/`j`/`k`/`l` | `ActivatePaneDirection "Left"/"Down"/"Up"/"Right"` | **new** — tmux `bind hjkl select-pane`. Avoids swallow-surprise for tmux reflexes. |
| `]` | `PasteFrom "Clipboard"` | **new** — tmux `bind ] paste-buffer`. |

Existing binds kept: `s`/`v` splits, `t` new tab, `n`/`p` tab-relative, `1-9` select tab,
`x` close pane, `&` close tab, `z` zoom, `,` rename tab, `$` rename workspace, `:` debug
overlay, `T` launcher, plus the WezTerm-only workspace niceties (`w`, `f`, `(`/`)`, `L`,
`S`) which have no tmux parallel and are deliberately retained.

The previous `Escape → PopKeyTable` cancel is removed by design (decision: tmux-faithful
"swallow + backstop"). To dismiss the prefix without acting: press any unbound key (it is
swallowed and the table pops), or use the backstop (§5).

### 3. Send-prefix detail

`SendKey{ key = " ", mods = "CTRL" }` re-emits what `Ctrl+Space` normally produces — NUL
(`C-@`). Harmless to pwsh/PSReadLine. This is the literal-prefix passthrough tmux provides
via `send-prefix`.

### 4. `resize_mode` sub-table (repeatable, sticky)

New table in `config.key_tables`. `one_shot = false` keeps it active across repeats;
`Escape`/`q` exit. Mirrors tmux `bind -r ... resize-pane`.

```lua
resize_mode = {
    { key = "h",          action = act.AdjustPaneSize({ "Left",  1 }) },
    { key = "j",          action = act.AdjustPaneSize({ "Down",  1 }) },
    { key = "k",          action = act.AdjustPaneSize({ "Up",    1 }) },
    { key = "l",          action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "LeftArrow",  action = act.AdjustPaneSize({ "Left",  1 }) },
    { key = "DownArrow",  action = act.AdjustPaneSize({ "Down",  1 }) },
    { key = "UpArrow",    action = act.AdjustPaneSize({ "Up",    1 }) },
    { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "Escape",     action = act.PopKeyTable },
    { key = "q",          action = act.PopKeyTable },
}
```

Entered with `prefix → Shift+R`. Coexists with the global `Meta+hjkl` resize (no prefix);
this is the tmux-style alternative the user asked to include. Step size 1 for fine control
(tmux's plain `C-arrow` is also 1; `M-arrow` is 5 — out of scope here).

### 5. Copy mode (`copy_mode`) + backstop

- **Entry:** `prefix → Escape` (tmux) **and** WezTerm's default `Ctrl+Shift+X` is kept.
- **Table:** start from `wezterm.gui.default_key_tables().copy_mode` (already vi-style ≈ the
  user's `copy-mode-vi`), then overlay a tmux tweak: `Enter` → copy-and-close (tmux
  `copy-mode-vi Enter send -X copy-selection-and-cancel`). De-dupe any pre-existing `Enter`
  binding so ours wins.

```lua
local copy_mode = wezterm.gui.default_key_tables().copy_mode
-- strip any default Enter binding, then add the tmux copy-and-exit
local filtered = {}
for _, m in ipairs(copy_mode) do
    if not (m.key == "Enter" and (m.mods == nil or m.mods == "NONE")) then
        table.insert(filtered, m)
    end
end
table.insert(filtered, {
    key = "Enter", mods = "NONE",
    action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
})
config.key_tables.copy_mode = filtered
```

Defaults already cover `v`/`V`/`Ctrl+v` select, `y` yank-to-clipboard+exit, `/`+`n`/`N`
search, `g`/`G` top/bottom, `Ctrl+u`/`Ctrl+d` half-page, `Ctrl+b`/`Ctrl+f` page,
`q`/`Esc`/`Ctrl+c`/`Ctrl+g` exit — i.e. the user's tmux copy-mode-vi muscle memory.

- **Paste:** `prefix → ]` (§2).
- **Backstop:** global `Ctrl+Shift+Space → ClearKeyTableStack` (added via
  `table.insert(config.keys, …)` inside the `is_windows` block). `Ctrl+Shift+Esc` is *not*
  used — Windows reserves it for Task Manager and WezTerm never receives it.

### 6. Documentation

Update `.config/wezterm/KEYBINDS.md`: timeout 1000ms → none/indefinite; document
send-prefix, swallow-on-unbound, `r`/`Shift+R`, `hjkl`, `Escape`=copy-mode, `]`=paste,
copy-mode keys, and the `Ctrl+Shift+Space` backstop.

## Risks & edge cases

1. **`one_shot=true` + `prevent_fallback=true` composition (primary unknown).** Expected:
   an unbound key is swallowed *and* the table pops (single keypress). If empirically the
   table does **not** pop on an unbound key (you stay in prefix), the fallback is to keep
   `prevent_fallback` and rely on the `Ctrl+Shift+Space` backstop + the fact that any *bound*
   key still exits. **Must be verified live** (test matrix below) before claiming done.
2. **Sub-table lock-out.** `resize_mode` is `one_shot=false`; it always provides `Escape`
   and `q` exits, and the backstop clears the stack. `copy_mode` keeps default exits.
3. **`Ctrl+Shift+Esc` reservation** — avoided (see §5).
4. **Send-prefix NUL** — `Ctrl+Space` → NUL is inert in pwsh; documented, not a blocker.
5. **smart-splits coexistence** — `resize_mode`'s bare `hjkl` only bind while that table is
   active; global `Ctrl+hjkl`/`Meta+hjkl` are unaffected.
6. **`wezterm.gui.default_key_tables()` availability at config-eval time** — used per docs
   for this exact purpose; if it errors, fall back to an explicit minimal `copy_mode` table.

## Verification plan (manual — config change, no automated harness)

Reload config (save triggers auto-reload; the stack also resets on reload). On a **native
pwsh** pane:

1. **No timeout:** `Ctrl+Space`, wait >3s, press `v` → split still fires (no expiry). Status
   bar shows the LEADER indicator throughout.
2. **Send-prefix:** `Ctrl+Space Ctrl+Space` → NUL reaches the shell (no split, no leader hang).
3. **Swallow:** `Ctrl+Space` then an unbound key (e.g. `9`… or a deliberately-unbound punct)
   → nothing typed into the shell; prefix exits.
4. **Splits / tabs / panes:** `s`, `v`, `t`, `x`, `z`, `n`/`p`, `1-9`, `hjkl` behave as mapped.
5. **Reload vs resize:** `r` reloads; `Shift+R` enters resize, `hjkl`/arrows repeat, `Escape`/`q` exit.
6. **Copy mode:** `Escape` (and `Ctrl+Shift+X`) enter copy mode; `v` select, `y`/`Enter`
   copy to clipboard + exit, `/` search, `q`/`Esc` exit; `]` pastes.
7. **Backstop:** while in `resize_mode`, `Ctrl+Shift+Space` returns to normal.
8. **Isolation:** in a **WSL** pane and a **Zellij** pane, `Ctrl+Space` still passes through
   (real tmux / stock Zellij), unaffected.

## File-by-file change list

- `.config/wezterm/wezterm.lua`
  - `:280-288` — drop `timeout_milliseconds`, add `prevent_fallback = true`.
  - `:336-428` `leader_mode` — `Escape`→`ActivateCopyMode`; add `Ctrl+Space` send-prefix,
    `r` reload, `Shift+R` resize entry, `hjkl` pane direction, `]` paste.
  - `config.key_tables` — add `resize_mode`; add `copy_mode` (default + `Enter` tweak).
  - `is_windows` block — `table.insert(config.keys, …)` for `Ctrl+Shift+Space`
    `ClearKeyTableStack`.
- `.config/wezterm/KEYBINDS.md` — documentation refresh.

## Out of scope / future

- `Meta+arrow` step-5 resize and `prefix + Ctrl+arrow` direct repeatable resize (kept simple
  with `Shift+R` sticky mode).
- Porting any of this to macOS/Linux (real tmux there).
- tmux session ↔ WezTerm workspace parity beyond the existing workspace binds.
