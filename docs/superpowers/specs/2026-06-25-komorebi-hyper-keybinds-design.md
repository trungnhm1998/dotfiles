# Komorebi Hyper-key keybinds — conflict-resolution design

- **Date:** 2026-06-25
- **Status:** Approved design (brainstorming) → pending implementation plan
- **Scope:** Windows only. Resolves the Alt-modifier collision between Komorebi (AHK) and Zellij. Companion to the [Zellij on Windows adoption design](./2026-06-25-zellij-windows-adoption-design.md).

## Problem / motivation

Komorebi's hotkeys (driven by `.config/komorebi/komorebi.ahk`) and Zellij's default keybinds both lean heavily on **Alt**, so they collide inside the terminal. The collision is **asymmetric and always lost by Zellij**: AHK binds like `!h::` install a low-level keyboard hook that *swallows* the keystroke (bare `!h`, no `~` prefix) before WezTerm/Zellij ever receive it. So every Alt combo Komorebi binds is dead-on-arrival in any terminal pane.

Live collisions today (Komorebi wins all):

| Alt combo | Komorebi (`komorebi.ahk`) | Zellij default |
|---|---|---|
| `Alt+h/j/k/l` | focus window (`:16-19`) | move focus / tab |
| `Alt+f` | toggle-monocle (`:55`) | toggle floating |
| `Alt+[` / `Alt+]` | cycle-stack (`:44-45`) | swap layout |
| `Alt+←↓↑→` | stack (`:39-42`) | move focus |

(`Alt+n` is *not* currently a live collision — Komorebi's `!n` is commented out at `:26`, so Zellij already receives it. The fix below makes the whole Alt namespace cleanly Zellij's.)

## Decision

**Move Komorebi entirely off Alt onto the Hyper key**, freeing Alt for the terminal. This both ends the collision and, as a bonus, *re-enables* Zellij's native Alt shortcuts inside panes (they were only ever shadowed, never unbound).

### Why Hyper, not the literal Win key

The user already produces **Hyper** (Ctrl+Alt+Shift+Win) and **Meh** (Ctrl+Alt+Shift) as single physical keys via a ZSA/QMK keyboard, which removes the usual reason people avoid Hyper.

- The literal **Win key** is the i3/Super instinct, but on Windows 11 via AHK it is a running skirmish with the OS: **Win+L / Win+W / Win+D / Win+P / Win+U are OS-reserved and unreclaimable** by AHK ([Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/4042535/why-does-command-l-lock-the-screen-why-cant-i-rema), [AHK forum](https://www.autohotkey.com/boards/viewtopic.php?t=22131)); **Win+1–9** is hard-bound to taskbar apps and collides head-on with a digit-based workspace scheme; plus Aero Snap, Task View, virtual desktops. `whkd` v0.2.4+ can override most of these, but this setup uses **AHK**, which cannot. ([komorebi discussion #837](https://github.com/LGUG2Z/komorebi/discussions/837))
- **Hyper** is a near-private namespace — almost nothing binds all four modifiers — so Komorebi gets a clean layer for one reversible registry tweak (below). ([Hyper-key on Windows](https://windowsforum.com/threads/turn-caps-lock-into-a-hyper-key-on-windows-with-autohotkey.395499/), [MakeUseOf](https://www.makeuseof.com/remap-caps-lock-to-hyper-key-and-double-shortcuts/))
- Komorebi delegates all hotkeys to whkd or AHK; nothing in komorebi core changes. ([komorebi](https://github.com/LGUG2Z/komorebi), [AHK docs](https://lgug2z.github.io/komorebi/common-workflows/autohotkey.html))

## The constraint that shapes the keymap

The i3 idiom **`$mod+key` = focus, `$mod+Shift+key` = move** *cannot* work with Hyper, because Hyper already contains Shift — `Hyper+h` and `Hyper+Shift+h` are the identical chord. The focus-vs-move distinction must move to a different axis.

**Chosen approach (A): Hyper + Meh split.** Use both physical keys the user already has:

- **Hyper = focus / act** on the current selection.
- **Meh = move / relocate** the window (and the "previous/secondary" variants).

Rejected alternatives: (B) Hyper-only with move on arrows + a resize mode — keeps Meh free but less symmetric; (C) stateful i3-style modes in AHK — most keys-free but adds bug surface. (A) wins because both keys exist and it preserves finger memory (`hjkl`/digits unchanged; only the base key changes).

## Proposed keymap

`Meh = ^!+` (Ctrl+Alt+Shift) · `Hyper = ^!+#` (adds Win), in AHK v2 notation.

### Hyper — focus / act layer

| Action | Keys | AHK |
|---|---|---|
| Focus L/D/U/R | Hyper+h/j/k/l | `^!+#h` … |
| Focus workspace 1–10 | Hyper+1…0 | `^!+#1::focus-workspace 0` … |
| Cycle focus prev/next | Hyper+[ / ] | `^!+#[` / `^!+#]` |
| Focus monitor 0/1 | Hyper+, / . | `^!+#,` / `^!+#.` |
| Resize edge L/D/U/R (increase) | Hyper+←/↓/↑/→ | `^!+#Left` … |
| Toggle float / monocle | Hyper+t / f | `^!+#t` / `^!+#f` |
| Flip layout H / V | Hyper+x / y | `^!+#x` / `^!+#y` |
| Cycle layout next | Hyper+c | `^!+#c` |
| Close / minimize | Hyper+q / m | `^!+#q` / `^!+#m` |
| Restart komorebi | Hyper+Backspace | `^!+#BS` |
| Suspend AHK hotkeys | Hyper+Home | `^!+#Home::Suspend` |

### Meh — move / relocate layer

| Action | Keys | AHK |
|---|---|---|
| Move window L/D/U/R | Meh+h/j/k/l | `^!+h` … |
| Move-to-workspace 1–10 | Meh+1…0 | `^!+1::move-to-workspace 0` … |
| Cycle move-to-workspace prev/next | Meh+p / n | `^!+p` / `^!+n` |
| Move-to-monitor 0/1 | Meh+, / . | `^!+,` / `^!+.` |
| Stack L/D/U/R | Meh+←/↓/↑/→ | `^!+Left` … |
| Unstack | Meh+; | `^!+;` |
| Cycle stack prev/next | Meh+[ / ] | `^!+[` / `^!+]` |
| Cycle layout prev | Meh+c | `^!+c` |
| Retile | Meh+r | `^!+r` |
| Toggle pause | Meh+q | `^!+q` |

## AHK modifier-superset caveat (must handle)

AHK tolerates *extra* modifiers: a `^!+X` (Meh) hotkey still fires when Win is also held, **unless** a more-specific `^!+#X` (Hyper) hotkey exists, which then wins. For keys bound on **both** layers (h/j/k/l, digits, arrows, `[`, `]`, `,`, `.`, `c`, `q`) this resolves correctly. The risk is **Meh-only keys with no Hyper twin** — `p`, `n`, `r`, `;` — where pressing Hyper would silently bleed into the Meh action.

**Mitigation:** add explicit Hyper-side guard bindings for `p`, `n`, `r`, `;` (either deliberate actions or `return` no-ops) so behavior is defined, not accidental. The implementation step verifies no cross-firing.

**Bulletproof alternative (optional, deferred):** remap the Hyper/Meh keys in the ZSA/QMK layout to unique keycodes (e.g. F24/F23) and use AHK custom combos (`F24 & h::`). This eliminates all modifier ambiguity *and* the registry tweak, at the cost of a one-time firmware edit that lives outside this repo. Not in the core plan. ([sample komorebi+AHK configs](https://github.com/JustAn0therDev/auto-hot-key-komorebi-configs))

## Registry enabler (required for the Hyper chord)

Windows reserves the bare four-modifier press to launch Office/Copilot, so tapping Hyper without a following key would pop that UI. Neutralize with one **per-user, reversible** edit, added idempotently to `deploy_windows.ps1`:

- Apply: `REG ADD HKCU\Software\Classes\ms-officeapp\Shell\Open\Command /t REG_SZ /d rundll32`
- Undo:  `REG DELETE HKCU\Software\Classes\ms-officeapp\Shell\Open\Command /f`

Source: [AHK board — prevent Win+Ctrl+Alt+Shift Office dialog](https://www.autohotkey.com/boards/viewtopic.php?t=65573).

## Zellij / WezTerm impact (near-zero)

- **No functional change to `.config/zellij/config.kdl`.** Freeing Alt un-shadows Zellij's existing Alt defaults (`Alt+n` new pane, `Alt+f` floating, `Alt+hjkl` move-focus). Add one clarifying comment that Alt is now intentionally Komorebi-free.
- The existing `Ctrl+Space` (tmux mode) and `Ctrl+hjkl` (vim-zellij-navigator) binds are untouched.
- **Verify, don't change:** (1) WezTerm passes Left-Alt through as Meta so Zellij receives `Alt+*`; (2) nvim-inside-Zellij does not contend for the same Alt combos (nav is `Ctrl+hjkl`, so no clash expected).

## Deploy

- `komorebi.ahk` lives in the repo at `.config/komorebi/` and is symlinked via `KOMOREBI_CONFIG_HOME` → editing the repo file is **live**; apply by re-running the AHK script.
- `deploy_windows.ps1` gains the idempotent `REG ADD` above, alongside the existing env-var setup.
- **Portability fallback (optional, deferred):** on a machine without the QMK keyboard, a `CapsLock→Hyper` remap (AHK, or **kanata** — already used on macOS) restores the key. Out of scope for the core change.

## Acceptance criteria

1. Tapping Hyper alone pops no Office/Copilot UI (registry tweak verified).
2. In a Zellij pane, `Alt+f` / `Alt+n` / `Alt+hjkl` perform Zellij actions.
3. `Hyper+hjkl` focuses, `Meh+hjkl` moves, `Hyper+arrows` resizes, `Meh+arrows` stacks, `Hyper+1‑0` / `Meh+1‑0` switch/move workspaces.
4. The new `komorebi.ahk` has **no bare-Alt (`!`) bindings** outside the `^!+` / `^!+#` prefixes.
5. No cross-firing on the `p`, `n`, `r`, `;` guard keys.
6. `Ctrl+hjkl` still navigates nvim ↔ Zellij; existing tmux/WSL flows unchanged.

## Risks & mitigations

- **AHK v2 ↔ Komorebi instability** — a config maintainer reports v2 bugginess with Komorebi (this setup is on `v2.0.2`). Mitigation: official docs ship a v2 sample; `whkd` is the fallback daemon if it misbehaves. ([report](https://github.com/JustAn0therDev/auto-hot-key-komorebi-configs))
- **Modifier-superset bleed** (`p`/`n`/`r`/`;`) — guard bindings + verification; F24 variant removes it entirely.
- **WezTerm Alt passthrough** — verified in the acceptance checks before relying on Zellij's Alt binds.
- **Registry edit** — per-user (HKCU), reversible, applied via the admin deploy script with the documented undo.

## Open items

- Final choice for the `p`/`n`/`r`/`;` guards (deliberate action vs no-op) — settle in the plan.
- Whether to adopt the F24/F23 firmware variant now or defer (default: defer).

## Sources

- [komorebi](https://github.com/LGUG2Z/komorebi) · [AHK workflow docs](https://lgug2z.github.io/komorebi/common-workflows/autohotkey.html) · [Win-key discussion #837](https://github.com/LGUG2Z/komorebi/discussions/837)
- [Microsoft Q&A — Win+L reserved](https://learn.microsoft.com/en-us/answers/questions/4042535/why-does-command-l-lock-the-screen-why-cant-i-rema) · [AHK — reserved Win shortcuts](https://www.autohotkey.com/boards/viewtopic.php?t=22131)
- [Hyper key on Windows (AHK)](https://windowsforum.com/threads/turn-caps-lock-into-a-hyper-key-on-windows-with-autohotkey.395499/) · [MakeUseOf — Hyper key](https://www.makeuseof.com/remap-caps-lock-to-hyper-key-and-double-shortcuts/) · [AHK — Office 4-mod fix](https://www.autohotkey.com/boards/viewtopic.php?t=65573)
- [JustAn0therDev/auto-hot-key-komorebi-configs](https://github.com/JustAn0therDev/auto-hot-key-komorebi-configs)
