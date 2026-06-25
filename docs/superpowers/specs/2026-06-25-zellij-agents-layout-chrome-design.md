# Zellij `agents` layout — restore Frappe-themed UI chrome

- **Date:** 2026-06-25
- **Status:** Design (approved, pending spec review)
- **Branch:** `feat/zellij-windows`
- **Scope:** `.config/zellij/layouts/agents.kdl` (one file)

## Symptom

The `agents` layout (three pwsh panes for parallel Claude agents) looked
"unthemed / colors off" compared to a normal Zellij session — no tab bar, no
status bar, bare-looking panes.

## Investigation (what it was *not*)

The Catppuccin Frappe theme is correct and is being applied. Verified on this
machine (Zellij 0.44.3, scoop):

- `config.kdl:6` sets `theme "catppuccin-frappe"`; `zellij setup --check`
  reports **"[CONFIG FILE]: Well defined"** and resolves the symlinked config.
- The deployed config genuinely contains the theme line (dir symlink via
  `deploy_windows.ps1`; `ZELLIJ_CONFIG_DIR` set).
- Zellij's **built-in** `catppuccin-frappe` uses the modern UI-components format
  with faithful official values — e.g. `text_unselected.base 198 208 245`
  (`#C6D0F5`, Frappe Text), `background 41 44 60` (`#292C3C`, Mantle),
  `emphasis_0` = Peach, `emphasis_1` = Sky.
- `COLORTERM=truecolor` — not a quantization issue.

The official `catppuccin/zellij` port (`catppuccin.kdl`) is the *older* simple
16-color format; vendoring it would be a **downgrade**. No theme change is
warranted.

## Root cause

A custom `layout { … }` **replaces Zellij's default UI wholesale**. Zellij's
default layout (`zellij setup --dump-layout default`, 0.44.3) injects the chrome
explicitly:

```kdl
pane size=1 borderless=true { plugin location="tab-bar" }
pane
pane size=1 borderless=true { plugin location="status-bar" }
```

`agents.kdl` had none of that — it went straight to `tab { ps; ps; ps }`, so no
tab/status bars were drawn. The pane *frames* (on by default) were the only
themed element left, which read as "bare."

## Decision

Restore **full chrome** (tab-bar + status-bar) via a `default_tab_template`,
keep the theme untouched, and **name the pane invocations** so the
Frappe-themed frame titles read `agent-1/2/3`.

Rationale for full bars over compact/status-only: the status bar surfaces the
current mode, which matters given the custom `Ctrl+Space` Tmux-mode prefix and
`Ctrl+hjkl` nav binds; matches a normal session and is future-proof if more
tabs are added. (Verified against official docs: template invocations accept
extra attributes like `name=`; `name` sets the pane title; `default_tab_template`
+ `children` is the correct wrapper.)

## Resulting file

```kdl
// Three pwsh panes for running parallel claude agents.
// Start a NAMED session with this layout (so you can reattach by name):
//   zellij --new-session-with-layout agents --session agents   (short: zellij -n agents -s agents)
// Reattach after closing the terminal:
//   zellij attach agents
// NOTE: do NOT pair --layout/-l with --session/-s to CREATE a session — that combo expects an
// already-active session and fails with "Session 'agents' not found" (zellij #3734 / #3868).
// Use --new-session-with-layout/-n to start a fresh named session (also works from inside one).
// Pin a command to a pane by replacing `ps` with: pane command="claude" { cwd "D:/projects/…" }
//
// default_tab_template re-adds the Frappe-themed chrome (tab-bar + status-bar). A custom `layout`
// REPLACES Zellij's default UI, so without this the themed bars never draw — only the pane frames
// do. `children` marks where this tab's panes go. Mirrors `zellij setup --dump-layout default`
// (0.44.3): bare plugin names, status-bar size=1.
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="tab-bar"
        }
        children
        pane size=1 borderless=true {
            plugin location="status-bar"
        }
    }
    pane_template name="ps" {
        command "pwsh"
        args "-NoLogo"
    }
    // Named invocations → the themed frame title of each pane reads agent-1/2/3.
    tab name="agents" focus=true {
        ps name="agent-1"
        ps name="agent-2"
        ps name="agent-3"
    }
}
```

## Out of scope

- **Theme files / palette** — unchanged; `catppuccin-frappe` stays as-is.
- **Pane arrangement** — `ps ps ps` keeps Zellij's default tiling. Forcing 3
  columns (`split_direction="vertical"`) is a deferred one-liner if wanted.
- **Other layouts / `config.kdl`** — untouched. The `default_tab_template`
  pattern is documented in-file for reuse if future custom layouts are added.

## Verification

Launch and visually confirm in WezTerm:

```
zellij -n agents -s agents
```

Pass criteria: Frappe-themed **tab bar** (top, "agents" tab), **status bar**
(bottom, shows mode), and **three `agent-N` frame titles** all render.

## References

- `zellij setup --dump-layout default` (0.44.3) — authoritative chrome snippet.
- Zellij docs — Creating a Layout: pane templates accept overriding attributes;
  `name` sets pane title; `default_tab_template` + `children`.
- `zellij setup --check` — confirmed config + theme resolve on this machine.
