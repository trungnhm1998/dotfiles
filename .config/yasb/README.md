# YASB — Windows status bar

Replaces komorebi-bar (egui) with [YASB](https://github.com/amnweb/yasb) (Qt).
Minimal v1: komorebi workspaces + clock.

- **Config:** `config.yaml` (bar + widgets), `styles.css` (Catppuccin Frappe).
- **Deployed by:** `deploy_windows.ps1` symlinks this dir to `~/.config/yasb`.
- **Autostart (one-time):** `yasbc enable-autostart` (disable: `yasbc disable-autostart`).
- **Launch now:** `yasb`  ·  **List monitors:** `yasbc monitor-information`.

## Work-area reservation
komorebi reserves the top strip via `global_work_area_offset` in
`../komorebi/komorebi.json` — komorebi-bar's own offset is inert once
`bar_configurations` is empty. Tune `top` to the rendered bar height.

## Rollback to komorebi-bar
In `../komorebi/komorebi.json`: restore
`"bar_configurations": ["$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor1.json", "$Env:KOMOREBI_CONFIG_HOME/komorebi.bar.monitor2.json"]`,
remove `global_work_area_offset`, then `yasbc disable-autostart` and restart komorebi.
