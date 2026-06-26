# YASB — Windows status bar

An auto-hiding, segmented [YASB](https://github.com/amnweb/yasb) (Qt) bar themed
Catppuccin Frappe — floating pills, colorful-per-segment, hidden until needed
(OLED-friendly). Replaces komorebi-bar (egui).

- **Config:** `config.yaml` (bars + widgets), `styles.css` (theme / Qt QSS).
- **Deployed by:** `deploy_windows.ps1` symlinks this dir to `~/.config/yasb`.
- **Autostart (one-time):** `yasbc enable-autostart` (off: `yasbc disable-autostart`).
- **Apply edits:** `yasbc reload`.  ·  **Monitors:** `yasbc monitor-information`.

## Layout

Two bars (`config.yaml` → `bars:`), per-monitor — primary rich, secondaries lean:

| Bar | Screen | Right cluster |
|-----|--------|---------------|
| `primary-bar` | `primary` (PG32UCDP 4K) | cpu · mem · gpu · net · weather · media · vol · mic · wifi · bt · tray · power |
| `secondary-bar` | `VI-01` (portrait) | *(empty — lean)* |

Both share **left** (workspaces · layout · per-workspace apps) and **center** (clock).

## Auto-hide (OLED)

`window_flags.auto_hide: true` on both bars: hidden until the cursor touches the
**top edge**, then tucks away ~½s after the cursor leaves. Also `hide_on_fullscreen`
(never pops over a real-fullscreen app/game) and `windows_app_bar: false` (floating —
reserves no work area).

> **No scripted workspace-switch peek.** `yasbc show-bar` can't hold the bar open while
> `auto_hide` is on — the CLI has no "pin", and auto_hide's timer re-hides it in ~½s
> (verified in v2.0.5 `bar_helper.py`: `AutoHideManager` + the Leave/QTimer). Reveal is
> hover-only by design.

## The gap around tiles

The uniform ~40px frame is **komorebi's** `default_workspace_padding: 30` +
`default_container_padding: 10` (`../komorebi/komorebi.json`) — *not* a bar work-area
reservation (`global_work_area_offset` is zeroed). The floating bar just appears over
the top of that gap on hover.

True edge-to-edge (gaps gone, for video/games): komorebi **service mode `f`**
(`toggle-maximize`) — distinct from `Hyper+F` monocle, which keeps the gaps.

## Gotchas (read before editing)

- **Font name must be `JetBrainsMono NF`** — the actual installed family. The Nerd Font
  spelling `'JetBrainsMono Nerd Font'` matches nothing, so Qt falls back to glyphless
  `JetBrains Mono` and every icon renders as tofu. `Segoe UI Emoji` is chained after it
  for emoji/CJK in media titles. (List families:
  `[System.Drawing.Text.InstalledFontCollection]`.)
- **Icons are real PUA codepoints** (FontAwesome, e.g. ``) stored literally in
  `config.yaml`. Edit them in a Nerd-Font-aware editor that preserves the bytes — some
  tooling silently blanks PUA glyphs on rewrite.
- **Weather is `open_meteo`, keyless.** v2.0.5 takes **no** `latitude`/`longitude` in
  config. Click the weather pill (`on_left: toggle_card`) → the card opens a search box
  → type your city ("Ho Chi Minh City") → pick it; it caches to YASB's `weather.json`.
  (No API key in the repo — deliberate.)
- **Volume uses the `icons` dict**, not the deprecated `volume_icons` list (v2.0.5).
- **Reload after edits.** The `watch_config` watcher is unreliable across the Windows
  dir-symlink — run `yasbc reload`. (`Failed to read response. Err: 109` on reload is a
  harmless pipe-restart race; the reload still lands.)

## Rollback to komorebi-bar
Restore `bar_configurations` (the per-monitor `komorebi.bar.*.json`) in
`../komorebi/komorebi.json`, then `yasbc disable-autostart` and restart komorebi.
