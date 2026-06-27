# stackline vendor notes

Vendored into `.config/hammerspoon/stackline/` for the yabai stacking overlay (komorebi-parity
floating pills + app icons, Frappe Mauve focus).
Spec: `docs/superpowers/specs/2026-06-28-yabai-stackline-stacking-overlay-design.md`
Plan: `docs/superpowers/plans/2026-06-28-yabai-stackline-stacking-overlay.md`

- **Upstream:** `AdamWagner/stackline` (dormant since 2022-11; icons broken on newer macOS — issues #125, #131).
- **Vendored fork:** `poddarh/stackline` @ `34cd0c985a4c309efd2530b91309dbe406d1a7d3`
  (chosen for per-space caching → fast space-switching + rendering fixes; fallback was `braun-steven/stackline`).
- **Local patches:** none. The vendored tree is pristine. If any line is ever changed vs the fork,
  mark it `-- PATCH:` in-file and list it here with the reason.

## Config (ours, not the fork)

Overrides live in `.config/hammerspoon/stackline_config.lua`, applied per-key via
`stackline.config:set('dotpath', value)` **after** `stackline:init()` — never via `:init(userConfig)`,
whose merge is shallow (`stackline/stackline.lua:22` → `u.extend`) and would wipe default
`appearance` sub-keys. Decisions:

- `appearance.color = {0.792, 0.620, 0.902}` — Frappe Mauve `#ca9ee6` (= jankyborders active border,
  komorebi `stackbar_focused_text`).
- `appearance.appColors = {}` — **cleared.** This fork ships per-app colors (Chrome/iTerm2/Code), and
  `window.lua:249` does `appColors[self.app] or opts.color`, so leaving them set would render those
  apps' focused pills in their per-app color instead of Mauve. Clearing forces uniform Mauve.
- `appearance.showIcons = true`, `features.clickToFocus = false` (out of scope; skips the global eventtap).
- `paths.yabai = /opt/homebrew/bin/yabai` — Apple Silicon. **This fork already defaults to the homebrew
  path** (upstream defaulted to Intel `/usr/local/bin/yabai`); pinned anyway for clarity + fork-drift safety.
- `appearance.dimmer` — **not overridden;** the fork's default `3.5` is kept. (The plan's draft `2.5` was
  based on a stale assumption; tune live in `stackline_config.lua` if you want more/less focused contrast.)

## Refresh wiring

stackline self-subscribes to window create/move/destroy/focus via `hs.window.filter` (`stackline.lua:46-101`).
We add **only** `space_changed` + `display_changed` yabai signals (`yabairc`) as a hedge for stackline's
deprecated `hs.spaces.watcher`. Deliberately **not** `window_moved/resized` — stackline already handles
those, and routing them through `hs -c` would machine-gun during drags and flood Hammerspoon's main thread.

## Known limits

- **iTerm2 (and other character-cell-rounding terminals) can drop out of a *mixed* stack.** Verified by
  instrumenting `window.lua:iconFromAppName` during setup: the icon-resolution chain works for *every* app
  in isolation (iTerm2 → `com.googlecode.iterm2` → image OK), but in a yabai stack of iTerm2 + Terminal,
  `iconFromAppName` was **never called for iTerm2** — i.e. iTerm2's window was excluded from the frame-group
  *before* drawing, not failing at the icon. stackline groups stacked windows by frame (`stackId` / fuzzy
  `stackIdFzy`, `query.lua:50`); iTerm2 rounds its own window to character cells, so its frame lands off the
  other windows' frame and misses the group. A stack of two same-app windows (e.g. 2× Terminal) renders
  fine. **Possible tune:** raise `features.fzyFrameDetect.fuzzFactor` (default 30) so larger frame deltas
  still group — at the risk of false-grouping genuinely-distinct windows. Left at default (accepted as-is).
- **Multi-display stacks** are historically flaky upstream (issue #67). Single-display is the primary target.

## Re-syncing the fork

1. Re-clone the fork, diff against `.config/hammerspoon/stackline/`, re-apply any `-- PATCH:` lines (none today).
2. `find .config/hammerspoon/stackline -name '*.lua' -print0 | xargs -0 -n1 luac -p` (syntax), then reload HS
   (`hs -c "hs.reload()"` — note the pathwatcher *ignores* `/stackline/`, so vendored edits need a manual reload).
3. Re-run the manual acceptance: stack 2+ windows (`Meh+←`) → icon pills appear; focused pill Mauve;
   `Meh+]`/`Meh+[` moves the highlight; unstack → pills vanish (OnStack).
