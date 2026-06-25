# Zellij Stock Keybindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Back out the tmux-mimicry inside Zellij on Windows and adopt Zellij's stock default keybindings.

**Architecture:** Remove the custom `Ctrl+Space → Tmux` keybind so Zellij falls back to its default preset (prefix-free `Alt+hjkl` nav, modal `Ctrl-p/t/n/s/o`, on-demand `Ctrl+g` lock). Remove the nvim `Ctrl+hjkl` Zellij navigator so nvim split nav behaves the same in and out of Zellij. Keep WezTerm's leader emulation and its `zj`/`is_zellij_pane` detection (only a stale comment changes).

**Tech Stack:** Zellij 0.44.3 (KDL config), Neovim (LazyVim, Lua plugin specs), WezTerm (Lua), PowerShell 7. This is a **dotfiles repo with no automated test harness** (see `AGENTS.md`) — "verify" steps are config-validation commands (agent-runnable) and manual smoke checks (operator-run), not unit tests. Each is labelled.

## Global Constraints

Copied verbatim from the spec — every task implicitly includes these:

- **Windows only.** `.config/zellij/config.kdl` is symlinked on Windows; `.config/nvim` and `.config/wezterm` are shared across OSes. Edits to symlinked files take effect live (after the app reloads).
- **New commits only — no history rewrite.** Phase-C commits and the tangled `73f47ce` are stacked on `feat/zellij-windows`; do not rebase/amend/force.
- **Leave uncommitted Phase-C files alone.** `git status` shows modified `.config/zellij/layouts/agents.kdl` and `claude/settings.json` plus untracked docs. **Every `git add` in this plan uses EXPLICIT paths — never `git add -A` / `git add .`.**
- **Do NOT use `unbind`.** Zellij 0.44.x `unbind` silently no-ops outside the `normal` block (zellij #3850/#3627). We delete the custom block instead.
- **No `Co-Authored-By` / AI-attribution trailers in commits** (user's git rule).
- **Verified facts:** Alt is free for Zellij (`.config/komorebi/komorebi.ahk:8` — komorebi is on Hyper/Meh). Zellij 0.44.3. TUI keys Zellij grabs (Claude Code `Alt+P`) are handled by on-demand `Ctrl+g` locked mode (already in place — no work here).

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `.config/zellij/config.kdl` | Zellij settings + (currently) one custom keybind | Remove the `keybinds {}` block; refresh header comment |
| `.config/nvim/lua/plugins/zellij-nav.lua` | nvim↔Zellij `Ctrl+hjkl` navigator (Zellij-gated) | **Delete** |
| `.config/nvim/lua/plugins/tmuxnav.lua` | vim-tmux-navigator spec | Remove the `init` ZELLIJ-gating; refresh comment |
| `.config/nvim/lua/config/keymaps.lua` | `Ctrl+hjkl`→`TmuxNavigate*` (unix-guarded) | **No change** — guard excludes Windows (documented in Task 2) |
| `.config/wezterm/wezterm.lua` | Conditional `Ctrl+Space` handler | Comment-only fix at `:276` |
| `docs/superpowers/specs/2026-06-25-zellij-windows-adoption-design.md` | Prior adoption design | Add "superseded in part" banner |

---

### Task 1: Zellij — adopt the stock default preset

**Files:**
- Modify: `.config/zellij/config.kdl` (header comment lines 1-4; remove `keybinds {}` block lines 28-32)

**Interfaces:**
- Consumes: nothing.
- Produces: a `config.kdl` with no custom `keybinds` block → Zellij applies its built-in default preset.

- [ ] **Step 1: Refresh the header comment**

Edit `.config/zellij/config.kdl`. Replace the existing header (lines 1-4):

```kdl
// Zellij config — shared across OSes via ~/.config/zellij.
// Tmux keybinding mode is a Zellij default; we add Ctrl+Space as the mode prefix to
// match the existing tmux/WezTerm muscle memory. Ctrl+b stays bound as a fallback
// (useful if Ctrl+Space doesn't register — see Step 3).
```

with:

```kdl
// Zellij config — shared across OSes via ~/.config/zellij.
// Stock keybindings: we deliberately use Zellij's DEFAULT preset (NO custom keybinds block) —
// prefix-free Alt+hjkl nav, modal Ctrl-p/t/n/s/o, Ctrl+g locked mode. tmux is mimicked only in
// WezTerm's leader for native pwsh panes, not here. TUI keys Zellij grabs (e.g. Claude Code's
// Alt+P) pass through via on-demand Ctrl+g locked mode.
// Design: docs/superpowers/specs/2026-06-25-zellij-stock-keybindings-design.md
```

- [ ] **Step 2: Remove the custom keybinds block**

Edit `.config/zellij/config.kdl`. Delete the trailing block (the blank line 27 plus lines 28-32):

```kdl

keybinds {
    shared_except "tmux" "locked" {
        bind "Ctrl Space" { SwitchToMode "Tmux"; }
    }
}
```

The file now ends after the `default_shell "..."` line. Confirm no `keybinds` token remains:

Run: `git -C C:/Users/mint/dotfiles grep -n keybinds -- .config/zellij/config.kdl`
Expected: no output (exit 1) — the `keybinds` token is gone.

- [ ] **Step 3: Validate the config parses (agent-runnable)**

Run (PowerShell): `zellij setup --check`
Expected: prints the config/data/cache locations and `[ OK ]` lines; the `CONFIG FILE:` points at `…\.config\zellij\config.kdl` and reports it as valid ("Well defined"). No KDL parse error.

- [ ] **Step 4: Manual smoke test (operator-run)**

Open a fresh Zellij session (`zellij` in a WezTerm pane). Verify:
- The status bar shows stock modes (e.g. `Ctrl + p` Pane, `Ctrl + t` Tab, `Ctrl + g` Lock).
- `Ctrl+Space` does **not** enter "Tmux" mode (it is no longer bound; it is inert/ignored).
- `Alt+h/j/k/l` moves focus between panes (split first with `Alt+n` or `Ctrl+p` then `n`).
- `Ctrl+g` toggles Locked mode (status bar dims), and toggles back.

- [ ] **Step 5: Commit (explicit path)**

```bash
git -C C:/Users/mint/dotfiles add .config/zellij/config.kdl
git -C C:/Users/mint/dotfiles commit -m "feat(zellij): adopt stock default keybindings on Windows" -m "Remove the Ctrl+Space->Tmux custom bind so Zellij uses its default preset (Alt+hjkl nav, modal Ctrl-p/t/n/s/o, Ctrl+g lock). Keeps theme/persistence/copy/shell. Per docs/superpowers/specs/2026-06-25-zellij-stock-keybindings-design.md."
```

---

### Task 2: Neovim — remove the Zellij navigator, restore stock split nav

**Files:**
- Delete: `.config/nvim/lua/plugins/zellij-nav.lua`
- Modify: `.config/nvim/lua/plugins/tmuxnav.lua` (remove the `init` ZELLIJ-gating)
- Context (no change): `.config/nvim/lua/config/keymaps.lua:11-16`

**Interfaces:**
- Consumes: nothing.
- Produces: nvim with no Zellij navigator; `Ctrl+hjkl` does nvim window navigation in and out of Zellij.

**Why `keymaps.lua` is NOT touched:** its `Ctrl+hjkl`→`TmuxNavigate*` maps are guarded by `if vim.fn.has("mac") == 1 or vim.fn.has("unix") == 1` (`keymaps.lua:11`), so they never load on Windows. On Windows, with `zellij-nav.lua` deleted, `Ctrl+hjkl` falls to LazyVim's default window-nav maps (and, where vim-tmux-navigator's own maps apply, they fall back to `wincmd` since there is no `$TMUX`). Net: identical nvim split navigation in and out of Zellij — exactly the spec's requirement.

- [ ] **Step 1: Delete the navigator plugin spec**

Run: `git -C C:/Users/mint/dotfiles rm .config/nvim/lua/plugins/zellij-nav.lua`
Expected: `rm '.config/nvim/lua/plugins/zellij-nav.lua'` (staged deletion).

- [ ] **Step 2: Remove the ZELLIJ-gating from tmuxnav.lua**

Replace the entire contents of `.config/nvim/lua/plugins/tmuxnav.lua` with:

```lua
return {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    -- Seamless Ctrl+hjkl between nvim splits and tmux panes (macOS/Linux/WSL). On Windows there is
    -- no tmux, so :TmuxNavigate* falls back to nvim window moves. Zellij is stock (no navigator):
    -- see docs/superpowers/specs/2026-06-25-zellij-stock-keybindings-design.md.
}
```

(This drops the `init = function() … vim.g.tmux_navigator_no_mappings = 1 … end` block whose only purpose was to coexist with the now-deleted `zellij-nav.lua`.)

- [ ] **Step 3: Verify nvim config loads cleanly (agent-runnable)**

Run (PowerShell): `nvim --headless "+qa" 2>&1`
Expected: no Lua error traceback (clean exit; empty or banner-only output).

- [ ] **Step 4: Confirm the plugin is orphaned and uninstall it (agent-runnable)**

Run (PowerShell): `nvim --headless "+Lazy! clean" "+qa" 2>&1`
Expected: Lazy reports removing `zellij-nav.nvim` (or, if already absent, no mention of it). No errors.

- [ ] **Step 5: Manual smoke test (operator-run)**

In a Zellij session, split into two Zellij panes; run `nvim` in one and `:vsplit` inside it. Verify:
- `Ctrl+h/j/k/l` moves between the **nvim** splits (does not jump out to the other Zellij pane).
- `Alt+h/j/k/l` jumps focus to the adjacent **Zellij** pane (out of nvim).
- No `ZellijNavigate*` command exists: `:ZellijNavigateLeft` → E492 "Not an editor command".

- [ ] **Step 6: Commit (explicit paths)**

```bash
git -C C:/Users/mint/dotfiles add .config/nvim/lua/plugins/zellij-nav.lua .config/nvim/lua/plugins/tmuxnav.lua
git -C C:/Users/mint/dotfiles commit -m "feat(nvim): drop zellij-nav.nvim, restore stock split nav under Zellij" -m "Zellij is now stock (no Ctrl+Space prefix, no navigator). Delete zellij-nav.lua and remove the ZELLIJ gating in tmuxnav.lua so Ctrl+hjkl does nvim window nav in and out of Zellij; cross-pane is Alt+hjkl. keymaps.lua unchanged (its maps are unix-guarded, never load on Windows)."
```

---

### Task 3: WezTerm — correct the stale `Ctrl+Space` comment

**Files:**
- Modify: `.config/wezterm/wezterm.lua:276`

**Interfaces:**
- Consumes: nothing. Produces: nothing (comment-only; behavior unchanged).

**Rationale:** The `is_zellij_pane` branch is KEPT — it suppresses WezTerm's `leader_mode` inside Zellij panes (so `Ctrl+Space` can't hijack into WezTerm splits). Only the comment, which claimed "Zellij owns Ctrl+Space", is wrong under stock and must be fixed.

- [ ] **Step 1: Update the comment**

Edit `.config/wezterm/wezterm.lua`. Replace (line 276):

```lua
                -- WSL pane -> tmux; Zellij pane -> Zellij. Both own Ctrl+Space, pass it through.
```

with:

```lua
                -- WSL pane -> tmux owns Ctrl+Space. Zellij is stock and ignores Ctrl+Space; we still
                -- pass it through (not into leader_mode) so WezTerm's leader can't hijack it in Zellij.
```

- [ ] **Step 2: Verify WezTerm still parses the config (agent-runnable)**

Run (PowerShell): `wezterm --config-file C:/Users/mint/dotfiles/.config/wezterm/wezterm.lua ls-fonts --list-system *> $null; echo "exit=$LASTEXITCODE"`
Expected: `exit=0` (config Lua loaded without error). If `ls-fonts` is unavailable in this build, substitute `wezterm show-keys --lua` and confirm it prints without a Lua error.

- [ ] **Step 3: Commit (explicit path)**

```bash
git -C C:/Users/mint/dotfiles add .config/wezterm/wezterm.lua
git -C C:/Users/mint/dotfiles commit -m "docs(wezterm): correct stale Ctrl+Space comment for stock Zellij" -m "is_zellij_pane still suppresses WezTerm leader inside Zellij; stock Zellij ignores Ctrl+Space. Comment-only, no behavior change."
```

---

### Task 4: Docs — mark the adoption design superseded in part

**Files:**
- Modify: `docs/superpowers/specs/2026-06-25-zellij-windows-adoption-design.md` (top banner)

**Interfaces:**
- Consumes: nothing. Produces: nothing.

- [ ] **Step 1: Add the supersede banner**

Edit `docs/superpowers/specs/2026-06-25-zellij-windows-adoption-design.md`. Replace the title line:

```markdown
# Zellij on Windows — adoption design
```

with:

```markdown
# Zellij on Windows — adoption design

> **⚠️ Superseded in part (2026-06-25):** the keybinding & WezTerm-passthrough design here
> (Tmux-mode `Ctrl+Space` prefix, 3-way passthrough, `vim-zellij-navigator` / `zellij-nav.nvim`,
> and the `d394828` "non-nvim nav is Ctrl+Space then hjkl" decision) is **replaced by**
> [`2026-06-25-zellij-stock-keybindings-design.md`](2026-06-25-zellij-stock-keybindings-design.md):
> we adopt Zellij's **stock** keybindings instead. The persistence, agents-layout, perf-gate, and
> pwsh-default-shell rationale below still stand.
```

- [ ] **Step 2: Commit (explicit path)**

```bash
git -C C:/Users/mint/dotfiles add docs/superpowers/specs/2026-06-25-zellij-windows-adoption-design.md
git -C C:/Users/mint/dotfiles commit -m "docs(zellij): mark adoption design's keybinding sections superseded"
```

---

### Task 5: Full acceptance smoke test (operator-run, no commit)

**Files:** none. This task verifies the spec's acceptance criteria end-to-end in a live session. Run after Tasks 1-3 are committed and the apps have reloaded (restart Zellij and WezTerm; nvim restarted).

- [ ] **Step 1: Zellij stock behavior**
  - `.config/zellij/config.kdl` has no `keybinds` block (`git grep -n keybinds -- .config/zellij/config.kdl` → nothing).
  - `Alt+hjkl` moves focus between Zellij panes; status bar shows stock modes.

- [ ] **Step 2: nvim navigation**
  - In a Zellij pane running nvim with a split, `Ctrl+hjkl` moves between nvim splits only; `Alt+hjkl` jumps to the adjacent Zellij pane. No navigator plugin loads (`:Lazy` shows no `zellij-nav.nvim`).

- [ ] **Step 3: Claude Code Alt+P**
  - In a Claude Code pane, `Alt+P` is grabbed by Zellij; press `Ctrl+g` (lock) then `Alt+P` reaches Claude Code (cycle effort); `Ctrl+g` to unlock.

- [ ] **Step 4: WezTerm coexistence**
  - Native pwsh pane: `Ctrl+Space` activates WezTerm `leader_mode`.
  - WSL pane: `Ctrl+Space` still reaches tmux.
  - `zj`-launched Zellij pane: `Ctrl+Space` does **not** open WezTerm's leader (inert).

- [ ] **Step 5: Refresh continuity**
  - Update `.planning/continuity.md` (via `/close`) noting the stock-keybindings switch shipped, and that history tidy-up for the tangled `73f47ce` + Phase-C commits is still pending when the branch is quiescent.

---

## Notes for the implementer

- **Commit hygiene:** each task is one commit with explicit `git add` paths. Never `git add -A`/`.` — uncommitted Phase-C files (`agents.kdl`, `claude/settings.json`, untracked docs) must stay out of these commits.
- **Order:** Tasks 1-4 are independent and may be done in any order, but Task 5 (smoke test) runs last. Recommended order: 1 → 2 → 3 → 4 → 5.
- **Rollback:** each change is a single revertable commit; `git revert <sha>` restores the prior behavior. The WSL2/tmux and WezTerm-native flows are untouched throughout.
