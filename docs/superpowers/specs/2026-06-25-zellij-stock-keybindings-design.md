# Zellij on Windows — adopt stock keybindings (back out the tmux-mimicry)

- **Date:** 2026-06-25
- **Status:** Approved design (brainstorming) → pending implementation plan
- **Scope:** Windows only. Supersedes the keybinding/passthrough portions of
  `2026-06-25-zellij-windows-adoption-design.md` and the nav decision in commit `d394828`.

## Problem / motivation

The earlier adoption work mimicked tmux *inside* Zellij: `Ctrl+Space` → Zellij's "Tmux" keybinding
mode as a prefix, a 3-way WezTerm `Ctrl+Space` passthrough, and a seamless `Ctrl+hjkl` nvim↔Zellij
navigator (`zellij-nav.nvim`, with `vim-tmux-navigator` suppressed under Zellij).

In practice this fights Zellij's design rather than complementing it. Zellij is **modal by design**
with a live status bar that teaches its keys, and its native pane navigation is **prefix-free
`Alt+hjkl`**. Layering tmux's single-prefix model on top buys a fragile detection/passthrough layer
and a known `Ctrl+hjkl`-under-pwsh caveat (`Ctrl+j` arriving as `Enter`; zellij#5052 class) — all to
preserve muscle memory that mostly lives on a *different OS* (tmux here is macOS/Linux/WSL only).

**Decision: stop porting tmux into Zellij. Adopt Zellij's stock default keybindings on Windows and
remove the mimicry.** Keep mimicking tmux only where we actually want it — in WezTerm's leader for
*native* pwsh panes — exactly as today.

Community research backs this: the dominant advice for tmux users moving to Zellij is to run the
defaults (the status bar removes the memorization burden that justified a custom tmux keymap) and
only customize the one or two bindings you truly can't live without; a 1:1 tmux port fights the
tool. See **Sources**.

## Non-goals

- Not changing WezTerm's `Ctrl+Space` leader emulation for **native pwsh panes** — that is the
  Windows tmux-feel we *do* want, and it stays.
- Not touching WSL2 + tmux — the `Ctrl+Space` → tmux passthrough for WSL panes is preserved.
- Not removing Zellij persistence / agents layout / theme work — orthogonal, all kept.
- Not rewriting git history on `feat/zellij-windows` — Phase-C commits and the tangled `73f47ce`
  are stacked; this lands as **new commits only**.

## Decision record

- **Use Zellij's default preset** — not unlock-first, not `clear-defaults=true`. "Use the default"
  means *delete our custom keybinds* so Zellij's built-ins apply. unlock-first is the documented
  fallback if Zellij-grabbing-keys-inside-nvim ever becomes annoying.
- **Navigation:** stock `Alt+hjkl` between Zellij panes (prefix-free); nvim-native split navigation
  (`Ctrl+w` / `vim-tmux-navigator`'s `Ctrl+hjkl`) *within* nvim. No cross-tool navigator, no pane
  detection. Two clean layers: inside the editor vs. between panes.
- **TUI keys Zellij grabs** (Claude Code's `Alt+P` → `TogglePaneInGroup`, and the whole bare-`Alt`
  layer): handled by **on-demand `Ctrl+g` locked mode** — validated last session, zero config,
  immune to the `unbind` bug. See vault `[[Zellij Keybinding Passthrough to TUI Apps]]`.
- **Do not `unbind`.** Zellij 0.44.x `unbind` silently no-ops outside the `normal` block
  (zellij #3850 / #3627); `setup --check` reporting "Well defined" proves the config *parses*, not
  that an unbind took effect. Going stock sidesteps this entirely — we *delete* the custom block
  rather than unbind individual keys.
- **WezTerm `Ctrl+Space` handler + `zj` detection are KEPT, not removed** (correction to the initial
  sketch). The `is_zellij_pane` check suppresses WezTerm's leader *inside* Zellij panes, which is
  still wanted under stock — otherwise `Ctrl+Space` in a Zellij pane would open WezTerm's leader and
  let it split WezTerm panes around the session. The current handler already yields correct stock
  behavior (Zellij panes pass `Ctrl+Space` through; stock Zellij ignores it). Only the stale
  "Zellij owns Ctrl+Space" comment is updated.

## Environment facts (verified 2026-06-25)

- **Alt is free for Zellij.** komorebi moved to a Hyper/Meh scheme (`Hyper = ^!+#`, `Meh = ^!+`);
  `.config/komorebi/komorebi.ahk:8` — *"Alt is intentionally left ENTIRELY free for the terminal
  (Zellij). No bare-Alt binds."* So stock `Alt+hjkl` nav is unobstructed. This is what the recent
  Hyper-key migration set up (`10f9340` design, `20e2c2d` impl) and it **supersedes `d394828`**
  ("non-nvim pane nav is Ctrl+Space then hjkl, komorebi owns Alt").
- Zellij **0.44.3** (scoop). Current `.config/zellij/config.kdl` adds only
  `bind "Ctrl Space" { SwitchToMode "Tmux"; }` on top of defaults (no `clear-defaults`, and — despite
  a stale comment in `zellij-nav.lua` — no `Ctrl+hjkl` unbind is actually present).
- Default keymap (from `zellij setup --dump-config`): pane nav `Alt+hjkl` (`MoveFocusOrTab`), modal
  entries `Ctrl p/t/n/s/o`, `Ctrl g` → Locked, `Ctrl q` → Quit; tmux mode uses `"`/`%`/`c` for
  split/split/new-tab; `GoToTab 1..9` live only in Tab mode.
- nvim nav plugins: `.config/nvim/lua/plugins/zellij-nav.lua` (swaits/zellij-nav.nvim, gated on
  `vim.env.ZELLIJ`) + `.config/nvim/lua/plugins/tmuxnav.lua` (christoomey/vim-tmux-navigator, whose
  `init` sets `vim.g.tmux_navigator_no_mappings = 1` when `ZELLIJ` is set).
- WezTerm: `.config/wezterm/wezterm.lua:254-290` — conditional `Ctrl+Space` (WSL → tmux;
  `is_zellij_pane` → pass through; native pwsh → `leader_mode`). The `zj` wrapper sets the
  `zellij=1` WezTerm user var in `.config/powershell/Microsoft.PowerShell_profile.ps1:114-116`.

## Design — changes

### 1. Zellij config (`.config/zellij/config.kdl`)

Remove the entire custom block:

```kdl
keybinds {
    shared_except "tmux" "locked" {
        bind "Ctrl Space" { SwitchToMode "Tmux"; }
    }
}
```

→ Zellij applies its default preset. **Keep** everything else (theme `catppuccin-frappe`,
`session_serialization`, `serialize_pane_viewport`, `copy_on_select`, `scrollback_editor`,
`default_shell` pwsh) and their comments. Net behavior: `Alt+hjkl` pane nav, modal `Ctrl-p/t/n/s/o`,
`Ctrl+g` locked mode on demand.

> Note: `config.kdl` is the shared cross-OS file, but it is symlinked only on Windows today, so this
> is effectively Windows-only. If Zellij is later adopted on macOS/Linux, the stock default applies
> there too — which is the desired outcome, no guard needed (keybinds carry no OS-specific paths).

### 2. Neovim

- **Delete** `.config/nvim/lua/plugins/zellij-nav.lua` (removes the `Ctrl+hjkl` Zellij navigator).
- **Revert the ZELLIJ-gating** in `.config/nvim/lua/plugins/tmuxnav.lua` — drop the
  `if vim.env.ZELLIJ … tmux_navigator_no_mappings = 1` special-case so nvim window navigation behaves
  identically inside and outside Zellij. (Required: otherwise, with `zellij-nav.lua` gone, *no*
  plugin would map `Ctrl+hjkl` inside Zellij and the keys would fall to nvim defaults.)
- Inside a Zellij pane, nvim handles its own splits; crossing into adjacent Zellij panes is
  `Alt+hjkl`. Reconcile any `vim-smart-splits` interplay during implementation (full plugin scan).

### 3. WezTerm (`.config/wezterm/wezterm.lua`) — minimal

Keep the conditional `Ctrl+Space` handler and the `zj`/`is_zellij_pane` detection. Update only the
stale comment at `:276` ("WSL pane -> tmux; Zellij pane -> Zellij. Both own Ctrl+Space…") to reflect
stock reality: *stock Zellij ignores `Ctrl+Space`; we pass it through so WezTerm's `leader_mode` does
not hijack it inside a Zellij pane.* Native pwsh keeps `leader_mode`; WSL keeps tmux passthrough. No
functional change; confirm in the smoke test. Leave the `zj` wrapper as-is.

### 4. Docs

- This spec.
- Add a "superseded by" note to the keybinding/passthrough sections of
  `2026-06-25-zellij-windows-adoption-design.md` (and to the `d394828` nav decision) pointing here.

## Risks & mitigations

- **Lost seamless cross-boundary nav** (one key flowing vim-split → Zellij-pane) → accepted; two
  clean layers instead. If missed later, add the `zellij-autolock` + `fresh2dev/zellij.vim` pattern
  (stock-preserving — Zellij auto-locks when nvim is focused). Out of scope here.
- **Default preset grabs nvim's `Ctrl+o`/`Ctrl+t`** when nvim runs *inside* Zellij → low impact:
  heavy nvim editing happens in a direct WezTerm pane (the perf escape hatch), so Zellij panes are
  mostly pwsh/Claude; on-demand `Ctrl+g` lock covers exceptions; unlock-first is the escalation.
- **`zj`-wrapper dependency** (user var only set when launched via `zj`, not bare `zellij`) →
  unchanged from today; under stock you have no reason to press `Ctrl+Space` inside Zellij anyway.
  Acceptable; documented.
- **Uncommitted Phase-C files + tangled history** → new commits only; stage reverted files
  explicitly; no rebase / history rewrite while commits are stacked.

## Acceptance criteria

- `.config/zellij/config.kdl` has **no** custom `keybinds` block; `Alt+hjkl` moves focus between
  Zellij panes; the status bar shows stock modes.
- Inside nvim (in a Zellij pane), split navigation works and **no** Zellij navigator plugin loads;
  `Alt+hjkl` jumps out to adjacent Zellij panes.
- Claude Code's `Alt+P` (cycle effort) is reachable via on-demand `Ctrl+g` lock.
- Native pwsh pane: `Ctrl+Space` still activates WezTerm `leader_mode`; WSL pane: still reaches tmux;
  Zellij pane: `Ctrl+Space` does **not** open WezTerm's leader.
- The reverts land as new commits; no history rewrite.

## Open items

- Reconcile any `vim-smart-splits` plugin interplay during implementation (full nvim plugin scan).
- Smoke test: confirm `Ctrl+Space` inside a `zj`-launched Zellij pane is inert (passes through,
  Zellij ignores), and that `Alt+hjkl` nav is unobstructed by komorebi.

## Sources

- [Zellij vs Tmux — Typecraft](https://typecraft.dev/tutorial/zellij-vs-tmux) — try defaults first; status bar as the teaching mechanism.
- [Zellij vs Tmux: My Terminal Multiplexer Journey — mrpbennett.dev](https://www.mrpbennett.dev/2026/02/tmux-zellij) — don't recreate your tmux config wholesale.
- [From Zellij to Tmux Back to Zellij — VADOSWARE](https://vadosware.io/post/from-zellij-to-tmux-back-to-zellij/) — returns to tmux were over feature gaps, not keybindings.
- [zellij #3058 — tmux-only mode to prevent hotkey conflicts](https://github.com/zellij-org/zellij/discussions/3058) — the Ctrl-key/TUI conflict pattern.
- [swaits/zellij-nav.nvim](https://git.sr.ht/~swaits/zellij-nav.nvim) and [hiasr/vim-zellij-navigator](https://github.com/hiasr/vim-zellij-navigator) — the navigator approaches being removed.
- [fresh2dev/zellij.vim + zellij-autolock](https://github.com/fresh2dev/zellij.vim) — the stock-preserving seamless-nav fallback, if ever wanted.
